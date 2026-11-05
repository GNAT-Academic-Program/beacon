# beacon

Typed publish-subscribe messaging in Ada.

- Each topic is a generic instantiation. A subscriber to a
  `Telemetry_Topic` receives `Telemetry.Reading` values, not bytes.
- Each subscriber has a bounded protected queue.
- Each subscriber has one of two delivery modes: Reliable or Best_Effort.
- A UDP multicast bridge connects processes on a desktop.

GNAT Academic Program capstone project. Proposal title: _Beacon: Typed
Publish-Subscribe Messaging_.

## What it is

Beacon uses the same pattern as ROS2 and DDS. The scope is what a team
can build and prove in one year. A publisher writes typed values to a
topic. Each subscriber reads them through its own bounded queue. Ada
gives these advantages:

- **The type is the topic.** You write
  `package T is new Beacon.Topic (Reading, 32)`. The compiler then checks
  each `Publish` and `Receive` on `T`. The API has no `void*`, no cast,
  and no header field that the receiver must trust.
- **The delivery mode is a discriminant, not a flag.**
  - `Subscriber (Reliable)` never drops a message. When its queue is
    full, it blocks the publisher.
  - `Subscriber (Best_Effort)` drops its oldest message when its queue is
    full, and counts the drop.
  - `Dropped` is always 0 on a Reliable subscriber. A test can check this
    value.
- **All sizes are bounded.** Queue depth and subscriber count are
  generic parameters. Code in `src/` does not use the heap.
  `Beacon.Queue` is SPARK.

## What is in the seed

All code runs. This is a working v0, not a skeleton.

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
demo/net_publisher           sends readings over UDP ...
demo/net_subscriber          ... receives them, checks CRC, counts sequence gaps
tests/                       queue (wrap, drop-oldest), topic (fan-out, overflow), wire (CRC vector, rejects)
```

Set `BEACON_NETWORK=no` to build without `src/net/`. Use this for
targets that have no sockets.

Read `ARCHITECTURE.md` before you change the code.

`tests/COVERAGE.md` lists which behaviors the tests check.

## Milestones

1. **Prove `Beacon.Queue`.** `gnatprove --mode=all` must report no
   errors. The proof must show these properties:
   - The ring index arithmetic never goes outside the array.
   - `Fill` stays in range.
   - Drop-oldest keeps `Head` and `Tail` consistent.

   This is a small package and the first real proof. You will probably
   need `Relaxed_Initialization` on `Buffer`.
2. **Blocking behavior under load.**
   - Write a test where a Reliable subscriber is full. The publisher must
     block in `Publish`, and must continue when the subscriber reads.
   - Write a load test: N tasks for some minutes. At the end,
     `Dropped (Reliable)` must be 0. This must be true in each run.
3. **Decide the open decisions** (below). Then change the code to agree
   with each decision.
4. **Make the bridge honest.**
   - Measure loss on a real LAN, not on loopback. Report sequence gaps.
   - Decide what our [delivery modes](/ARCHITECTURE.md#delivery-modes)
     mean for Beacon's reliability.
5. **A second transport.** Serial (UART) is the best candidate. A
   board-to-board link uses serial. Serial also forces a framing decision
   (length prefix or delimiter). UDP datagrams do not need this decision.

## Open decisions (Week 4)

1. `Try_Publish` when a Reliable subscriber is full. Option A (current):
   partial delivery. The other subscribers get the message, and
   `Delivered` is False. Option B: all-or-nothing.
2. Registration is not task-safe. All registration must occur before the
   first `Publish`. Option A (current): keep this as a documented rule.
   Option B: make the registry a protected object. The in-process demo
   shows the failure: its tasks wait on a `Go` entry before they publish.
3. `Receive` blocks and has no timeout. Option A (current): keep this.
   Option B: add `Receive (S, Msg, Timeout, Success)`.
4. The registry holds `Subscriber'Unchecked_Access`. If a subscriber is
   declared in a scope that ends, the registry holds a dangling access.
   Option A (current): accept this, with the rule "declare subscribers at
   library level". Option B: change the design.

## Build

The project has four [Alire](https://alire.ada.dev) crates. The demo,
test and proof crates pin the library by path.

```
alr build                           # library, with src/net
BEACON_NETWORK=no alr build         # library, in-process only
cd tests && alr build && ./bin/queue_tests && ./bin/topic_tests && ./bin/wire_tests
cd demo  && alr build && ./bin/inproc_demo
# two terminals:
./bin/net_subscriber 239.255.0.1 5000 5
./bin/net_publisher  239.255.0.1 5000 1000
cd prove && alr exec -- gnatprove -P ../beacon.gpr --mode=flow   # SPARK flow analysis
cd prove && alr exec -- gnatprove -P beacon_prove.gpr            # SPARK proof of Beacon.Queue
```

Each build checks contracts at runtime (`-gnata`). Each build treats
warnings as errors.

## Design rules

The code refers to these rules by number.

1. **No bytes in the public API.** Each topic is a generic instantiation
   for one message type. A byte-buffer payload in the public API is a
   rejected design, for any reason.
2. **The delivery mode is part of the subscriber type.** Reliable never
   drops. Best_Effort drops the oldest message and counts the drop.
3. **Queues are bounded at instantiation.** A queue does not grow.
4. **The model is static.** Topics and participants are configured at
   compile time or at startup. Nothing is discovered at runtime.
   Subscribers register before the first `Publish`.
5. **`src/` has no network dependency.** `src/net/` needs no tasking
   runtime features beyond the features that `src/` needs.
6. **Wire frames and message codecs use records with representation
   clauses.** Do not use shifts and masks.
7. **The publisher writes to a subscriber's queue only through the
   protected type.**

See `CONTRIBUTING.md` for the fork workflow.

## Contact

Olivier Henley, GAP Coordinator, AdaCore. Weekly meeting and the project
Discord.

## License

Apache-2.0. See `LICENSE`.
