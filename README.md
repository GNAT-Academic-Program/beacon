# beacon

Typed publish-subscribe messaging in Ada. Topics are generic
instantiations, so a subscriber to a `Telemetry_Topic` receives
`Telemetry.Reading` values, never bytes. Bounded protected queues,
two explicit delivery modes, and a UDP multicast bridge for
cross-process use on the desktop.

GNAT Academic Program capstone project. Proposal title: _Beacon: Typed
Publish-Subscribe Messaging_.

## What it is

The pattern under ROS2 and DDS, scoped to what can be built and proved
in a year. A publisher writes typed values to a topic; any number of
subscribers read them through their own bounded queue. What makes it
worth doing in Ada:

- **The type is the topic.** `package T is new Beacon.Topic (Reading, 32)`
  and every `Publish`/`Receive` on `T` is checked by the compiler. No
  `void*`, no cast, no header field to trust.
- **Delivery mode is a discriminant, not a flag.** `Subscriber (Reliable)`
  never drops and blocks the publisher when full. `Subscriber
(Best_Effort)` drops its oldest and counts it. `Dropped` is always 0 on
  a Reliable subscriber; that is the checkable form of the promise.
- **Bounded everywhere.** Queue depth and subscriber count are generic
  parameters. No heap in `src/`. `Beacon.Queue` is SPARK.

## What is in the seed

Everything runs. This is a working v0, not a skeleton:

```
src/beacon.ads               Delivery_Mode                                       SPARK
src/beacon-queue.ads         generic bounded ring, Push/Pop/Push_Dropping_Oldest  SPARK, proof target
src/beacon-topic.ads         generic: Publisher, Subscriber (Mode), protected queue, static registry
src/net/beacon-wire.ads      14-byte frame header by rep clause, CRC-32, Encode/Decode
src/net/beacon-transport.ads Transport interface: Send / Receive
src/net/beacon-transport-udp UDP multicast over GNAT.Sockets
src/net/beacon-bridge.ads    generic: Egress task (local sub -> wire), Ingress task (wire -> local pub)
demo/telemetry.ads           message types + topic instantiations = the static registry
demo/telemetry-codecs        Serialize/Deserialize by overlay of a rep-claused record
demo/inproc_demo             1 kHz sensor + 10 Hz controller, checks both modes, exits non-zero on failure
demo/net_publisher           200 readings over UDP ...
demo/net_subscriber          ... received, CRC-checked, sequence gaps counted
tests/                       queue (wrap, drop-oldest), topic (fan-out, overflow), wire (CRC vector, rejects)
```

`BEACON_NETWORK=no` drops `src/net/` for targets without sockets.

Read `ARCHITECTURE.md` before touching anything.

## Milestones

1. **Prove `Beacon.Queue`.** `gnatprove --mode=all` clean: the ring
   index arithmetic never leaves the array, `Fill` stays in range,
   drop-oldest keeps head and tail consistent. Small package, first
   real proof. Expect to add `Relaxed_Initialization` on `Buffer`.
2. **Blocking semantics under load.** A test where a Reliable subscriber
   is full, the publisher blocks in `Publish`, and unblocks when the
   subscriber drains. Then a sustained load test: N tasks, minutes,
   `Dropped (Reliable) = 0` at the end. Always.
3. **Decide the open questions** (below), then change the code to match.
4. **Make the bridge honest.** Measure loss on a real LAN, not loopback.
   Report sequence gaps. Decide what our [delivery modes](/ARCHITECTURE.md#delivery-modes)
   mean for Beacon's reliability.
5. **A second transport.** Serial (UART) is the natural one: it is what
   a board-to-board link looks like, and it forces a framing decision
   (length prefix vs delimiter) that UDP datagrams hid.

## Open decisions (Week 4)

1. `Try_Publish` on a full Reliable subscriber: partial delivery
   (current: the others get it, `Delivered = False`) or all-or-nothing.
2. Registration is not task-safe and must precede any `Publish`. Keep
   as a documented rule (current), or make the registry a protected
   object. The in-process demo shows what happens when you get this
   wrong: it waits on a `Go` entry before publishing.
3. `Receive` blocks with no timeout. Keep, or add `Receive (S, Msg,
Timeout, Success)`.
4. Registry holds `Subscriber'Unchecked_Access`: a subscriber declared
   in a scope that exits leaves a dangling entry. Acceptable with the
   "declare at library level" rule, or redesign.

## Build

Three [Alire](https://alire.ada.dev) crates; demo and tests pin the
library by path.

```
alr build                           # library, with src/net
BEACON_NETWORK=no alr build         # library, in-process only
cd tests && alr build && ./bin/queue_tests && ./bin/topic_tests && ./bin/wire_tests
cd demo  && alr build && ./bin/inproc_demo
# two terminals:
./bin/net_subscriber 239.255.0.1 5000 5
./bin/net_publisher  239.255.0.1 5000 1000
alr with gnatprove && alr exec -- gnatprove -P beacon.gpr --mode=flow
```

Contracts are checked at runtime in every build (`-gnata`). Warnings
are errors.

## Rules of the road

- Topics are generic instantiations. A byte-buffer payload in the
  public API is a rejected design, whatever the reason.
- Queues are bounded at instantiation. No growth.
- `src/` has no network dependency; `src/net/` has no tasking runtime
  requirement beyond what `src/` needs.
- Wire framing is a record with a representation clause, not shifts
  and masks. Same for message codecs.
- The publisher never touches a subscriber's queue except through the
  protected type.

See `CONTRIBUTING.md` for the fork workflow.

## Contact

Olivier Henley, GAP Coordinator, AdaCore. Weekly meeting, plus the
project Discord.

## License

Apache-2.0. See `LICENSE`.
