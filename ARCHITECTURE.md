# Architecture

## Layers

```
application (demo/, or yours)
     |
Beacon.Topic  (generic)     Publisher, Subscriber (Mode), protected Bounded_Queue, static registry
     |
Beacon.Queue  (generic)     pure bounded ring buffer, no tasking          SPARK proof target
     |
Beacon                      Delivery_Mode                                 Pure, SPARK

--- src/net/, desktop only. The three packages above never refer to these. ---

Beacon.Bridge (generic)     Egress task: local Subscriber -> frames -> Transport
                            Ingress task: Transport -> frames -> local Publisher
     |               |
Beacon.Wire          Beacon.Transport         frame header by rep clause, CRC-32 / Send, Receive interface
                          |
                     Beacon.Transport.UDP     GNAT.Sockets multicast
```

Each package depends only on the packages below it. `Topic` and `Queue`
never use bytes. `Bridge` is a client of `Topic`, the same as an
application. The core packages do not know that a network exists.

## Why the ring buffer is outside the protected type

`Beacon.Queue` is plain data. It has no entries, no barriers, and no
runtime dependency. Its full interface is index arithmetic on a fixed
array, so it is the proof target. `Beacon.Topic` puts one queue in each
protected object and adds the barriers.

This split makes the work easier. The team proves the ring and tests the
protected wrapper. gnatprove can prove a protected type, but with more
difficulty.

`Empty_Queue` is the only correct initial value. `Buffer` is not
initialized on purpose, because `Element_Type` may have no default
value. The queue reads only the slots between `Head` and `Tail`.
`Element_Array` has `Relaxed_Initialization`, and the type invariant of
`Queue_Type` states that these slots are initialized.

The postconditions of `Beacon.Queue` state only `Count`. A Silver proof
(no runtime errors) does not show FIFO order. To prove FIFO order, add
functional contracts.

## Delivery modes

`Subscriber (Mode : Delivery_Mode)`. The mode is also a discriminant of
the protected queue. Thus each subscriber has its own `Push` entry
barrier: always open for `Best_Effort`, open when not full for
`Reliable`.

- Reliable: `Publish` blocks on that subscriber until it has room.
  `Try_Publish` sets `Delivered` to False and goes to the next
  subscriber. `Dropped` is always 0.
- Best_Effort: `Push` never blocks. When the queue is full, the oldest
  element is overwritten and `Drops` counts it.

Each topic instantiation has one writer. `Create_Publisher` refuses a
second writer.

`Publish` sends to the subscribers in registration order, with one
protected call for each subscriber. No lock covers all subscribers.
Thus a blocked Reliable subscriber stops publication to the subscribers
after it. If this is important, register Reliable subscribers first, or
use `Try_Publish`.

Beacon’s delivery modes control local queue overflow, not delivery
across the network. DDS reliability QoS addresses a different question:
whether communication between a writer and a reader includes recovery
of lost messages.

DDS BEST_EFFORT does not track receipt or resend lost messages.
DDS RELIABLE uses acknowledgements and retransmission to recover
losses. It does not automatically guarantee delivery of every message:
history settings determine which messages are retained for recovery,
and resource limits bound how much can be buffered. With KEEP_LAST,
newer messages can replace older, unacknowledged ones.
See the [RTI Connext documentation](https://community.rti.com/static/documentation/connext-dds/current/doc/manuals/connext_dds_professional/users_manual/users_manual/RELIABILITY_QosPolicy.htm).

Neither Beacon mode adds acknowledgements or retransmission to the UDP
bridge. On ingress, the bridge uses Try_Publish, so a full Reliable
subscriber can miss a message without increasing its Dropped count.
Dropped = 0 therefore means no queued messages were overwritten,
not that every published message arrived.

## The registry

The registry is a protected fixed array of `Max_Subscribers` access values.
Registration checks capacity and duplicates in the same protected operation as insertion.
Tasks may register different subscribers concurrently during startup.
Callers must finish registration before starting publication.

The first Publish or Try_Publish closes registration and copies the subscriber list.
Queue operations run after the registry lock is released because Reliable delivery can block.
Late registration raises `Ada.Assertions.Assertion_Error` without changing membership.
Concurrent registrations use protected-operation order as registration order.

Subscribers must remain alive while topic operations can access them.
The registry still stores caller-owned subscribers through `Unchecked_Access`.
This change does not solve dangling subscriber access.
Callers must serialize operations on the same Publisher.

## Wire

Each datagram holds one frame. The 14-byte header has these fields:
magic, topic id, sequence, length, and CRC-32. The CRC-32 covers the
header (with the checksum field set to 0) and the payload.

The header is an Ada record with a representation clause and
`Scalar_Storage_Order => High_Order_First`. An overlay puts it on the
byte array. The declaration gives network byte order. No code swaps
bytes.

`Decode` never raises an exception for bad input. It returns one of these
statuses:

- `Too_Short`: fewer bytes than the header.
- `Bad_Magic`: the magic field is wrong.
- `Bad_Length`: the frame is not exactly header + length bytes.
- `Bad_Checksum`: the CRC-32 does not agree.
- `Ok`.

CRC-32 is the IEEE 802.3 CRC (the same as zlib and PNG). `wire_tests`
has a test vector.

## Bridge

`Start_Egress` and `Start_Ingress` each allocate one task. The tasks are
never freed. The bridge is desktop only, so the heap is permitted there.

- **Egress** polls `Try_Receive` on its local subscriber every 1 ms. It
  sends one frame for each message. The sequence number increases by 1
  for each frame.
- **Ingress** polls the transport with a 100 ms timeout. For each frame
  it decodes the frame, checks the topic id, counts sequence gaps,
  deserializes the message, and calls `Try_Publish` locally. A full local
  subscriber thus cannot stop the network reader.
- **Stop** sets a flag. Each task ends at its next poll.

Results:

- A Reliable egress subscriber lets a slow network block the
  application's publisher.
- A Best_Effort egress subscriber lets the bridge drop messages before
  the network does.
- Neither mode makes UDP reliable. Milestone 4 is to document this
  correctly.

## Transport

`Beacon.Transport` is a limited interface with `Send` and `Receive (Timeout)`.
If `Send` raises `Would_Block`, it has not sent the frame.
Egress retries that frame every 1 ms until `Send` succeeds or `Stop` is
requested.

`Beacon.Transport.UDP` uses multicast datagrams. It converts between
`Wire.Byte_Array` and `Stream_Element_Array` with an
`Unchecked_Conversion` on equal-sized arrays in one place.

`Beacon.Transport.Loopback` connects bridge instances without sockets.
Each instance has a protected, 16-slot FIFO. `Send` copies a datagram
into the FIFO; `Receive` removes one or times out. When the FIFO is full,
`Send` raises `Queue_Full`, an alias of `Would_Block`, without changing
the queue. Empty or oversized sends raise `Constraint_Error`. A receive
buffer that is too small discards its datagram and raises
`Constraint_Error`.

A serial transport is planned for milestone 5.

## Codecs

The user supplies one codec (Serialize and Deserialize) for each message
type to the bridge instantiation. The demo's `Reading` has a
representation clause with `High_Order_First`. Thus:

- `Serialize` is `Overlay := Msg`.
- `Deserialize` is `Msg := Overlay`, after a `'Valid_Scalars` check.

Use this pattern for each codec. If a codec needs shifts and masks, the
message type needs a representation clause.

## What is not here, on purpose

- **Dynamic discovery.** Topics are generic instantiations. Participants
  are configured, not discovered.
- **QoS beyond the two modes.** There are no deadlines, no history depth
  for each reader, and no ownership.
- **Retransmission.** A reliable transport over UDP is a full project.
  Measure the real loss first.
- **An embedded network transport.** With `BEACON_NETWORK=no`, the core
  builds on each runtime that has protected entries (light tasking or
  full). A ZFP runtime cannot host `Beacon.Topic`. Use `Beacon.Queue`
  directly on ZFP.
