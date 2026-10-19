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

--- src/net/, desktop only, never referenced by the three above ---

Beacon.Bridge (generic)     Egress task: local Subscriber -> frames -> Transport
                            Ingress task: Transport -> frames -> local Publisher
     |               |
Beacon.Wire          Beacon.Transport         frame header by rep clause, CRC-32 / Send, Receive interface
                          |
                     Beacon.Transport.UDP     GNAT.Sockets multicast
```

Dependencies point down only. `Topic` and `Queue` never see a byte.
`Bridge` is a client of `Topic` like any application; the network is
invisible to the core.

## Why the ring buffer is outside the protected type

`Beacon.Queue` is plain data: no entries, no barriers, no runtime. It
is the proof target because its whole surface is index arithmetic on a
fixed array. `Beacon.Topic` wraps one in a protected type and adds the
barriers. Proving the ring and testing the protected wrapper separately
is much easier than proving a protected type, which gnatprove handles
but with more friction.

`Empty_Queue` is the only well-formed initial value. `Buffer` is left
uninitialized on purpose (`Element_Type` may have no default); only
slots between `Head` and `Tail` are ever read. The proof will need
`Relaxed_Initialization` on `Buffer` to say that precisely.

## Delivery modes

`Subscriber (Mode : Delivery_Mode)`. The mode is a discriminant of the
protected queue too, so the `Push` entry barrier is chosen per
subscriber: `Best_Effort` always open, `Reliable` open when not full.

- Reliable: `Publish` blocks on that subscriber until it has room.
  `Try_Publish` reports `Delivered = False` and skips it. `Dropped` is
  always 0.
- Best_Effort: `Push` never blocks; when full the oldest element is
  overwritten and `Drops` counts it.

One writer per topic instantiation. `Create_Publisher` refuses a second.
Fan-out is per subscriber in registration order, one protected call
each; there is no global lock across subscribers, so a blocked Reliable
subscriber holds up publication to the ones after it. Keep Reliable
subscribers first if that matters, or use `Try_Publish`.

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

A fixed array of `Max_Subscribers` access values, filled by
`Create_Subscriber` with `S'Unchecked_Access`. Not protected: register
at startup, before any `Publish`, from one task. The in-process demo
shows the failure when this is ignored (tasks activating before `main`
registers) and the cure (a `Go` entry). Whether to make registration
protected is a Week 4 decision.

## Wire

One frame per datagram. 14-byte header: magic, topic id, sequence,
length, CRC-32 over header (checksum zeroed) plus payload. The header
is an Ada record with a representation clause and
`Scalar_Storage_Order => High_Order_First`, overlaid on the byte
array. Network byte order comes from the declaration, not from code.
`Decode` is total: `Too_Short`, `Bad_Magic`, `Bad_Length` (the frame
must be exactly header + length), `Bad_Checksum`, or `Ok`.

CRC-32 is the IEEE 802.3 one (zlib, PNG). Test vector in `wire_tests`.

## Bridge

Two task types, allocated once per `Start_*`, never freed (desktop
only; a heap is fine there). Egress polls `Try_Receive` on its local
subscriber at 1 kHz and sends a frame per message with an incrementing
sequence. Ingress polls the transport with a 100 ms timeout, decodes,
checks the topic id, counts sequence gaps, deserializes, and
`Try_Publish`es locally so a stuck local subscriber cannot stall the
reader. `Stop` sets a flag; tasks exit at their next poll.

Egress with a Reliable subscriber means a slow network blocks the
application's publisher. Egress with Best_Effort means the bridge drops
before the wire does. Neither makes UDP reliable. Milestone 4 is
writing that down properly.

## Transport

`Transport` is a limited interface with `Send` and `Receive (Timeout)`.
UDP is the one implementation. Conversion between `Wire.Byte_Array`
and `Stream_Element_Array` is an `Unchecked_Conversion` on same-sized
arrays, in one place. A loopback in-memory transport for tests is a
good first addition; a serial one is milestone 5.

## Codecs

Per message type, supplied to the bridge instantiation. The demo's
`Reading` has a representation clause with `High_Order_First`, so
`Serialize` is `Overlay := Msg` and `Deserialize` is
`Msg := Overlay` guarded by `'Valid_Scalars`. That is the pattern: if
a codec needs shifts and masks, the message type is missing a
representation clause.

## What is deliberately not here

- Dynamic discovery. Topics are generic instantiations; participants
  are configured, not found.
- QoS beyond the two modes. No deadlines, no history depth per reader,
  no ownership.
- Retransmission. A reliable transport over UDP is a project in itself;
  do the honest measurement first.
- An embedded network transport. `BEACON_NETWORK=no` gives the core
  on any runtime with protected entries (light tasking or full). ZFP
  cannot host `Beacon.Topic`; use `Beacon.Queue` directly there.
