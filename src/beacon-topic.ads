--  Beacon.Topic: one instantiation for each message type.
--
--     package Telemetry_Topic is new Beacon.Topic
--       (Message_Type => Telemetry_Reading, Queue_Depth => 32);
--
--  A publisher sends only Message_Type values, and a subscriber receives
--  only Message_Type values. No other path exists (design rule 1).
--
--  Static model (design rule 4): each instantiation has a fixed table of
--  Max_Subscribers entries. Rules for the user:
--    * Register each subscriber at startup, before the first Publish.
--    * Tasks may register different subscribers concurrently at startup.
--    * Finish registration before Publish or Try_Publish begins.
--  The first publication closes registration, even with no subscribers.
--  Calls on the same Publisher must remain serialized by the caller.
--  Subscribers must remain alive while any topic operation can access them.
--
--  Single writer: each instantiation has one Publisher. Create_Publisher
--  refuses a second one.
--
--  Runtime: this package needs protected types with entries. Use a
--  light-tasking (Ravenscar or Jorvik) or full runtime. A ZFP runtime
--  cannot host this package; use Beacon.Queue directly on ZFP.

with Beacon.Queue;

generic
   type Message_Type is private;
   Queue_Depth     : Positive;
   Max_Subscribers : Positive := 8;
package Beacon.Topic is

   type Publisher is limited private;
   type Subscriber (Mode : Delivery_Mode) is limited private;

   ---------------
   -- Publisher --
   ---------------

   --  True after Create_Publisher has run for this instantiation.
   function Has_Publisher return Boolean;

   --  True after Create_Publisher has run on P.
   function Is_Created (P : Publisher) return Boolean;

   --  Makes P the one publisher of this instantiation.
   procedure Create_Publisher (P : in out Publisher)
     with Pre  => not Has_Publisher and then not Is_Created (P),
          Post => Has_Publisher and then Is_Created (P);

   --  Sends Msg to each registered subscriber, in registration order.
   --  Reliable subscriber with a full queue: Publish blocks until the
   --  queue has room. While Publish blocks, the subscribers registered
   --  after this one do not get Msg.
   --  Best_Effort subscriber with a full queue: the oldest message is
   --  dropped and counted. Publish does not block.
   --  With zero registered subscribers, Publish does nothing.
   procedure Publish (P : Publisher; Msg : Message_Type)
     with Pre => Is_Created (P);

   --  Sends Msg to each registered subscriber that has room, and does not
   --  block. Delivered is False if one or more Reliable subscribers were
   --  full. Those subscribers do not get Msg. All other subscribers get
   --  Msg (partial delivery).
   --  Open decision (README, Week 4): keep partial delivery, or change to
   --  all-or-nothing. Partial delivery is simpler and is the same as the
   --  per-reader queues of DDS.
   procedure Try_Publish
     (P         : Publisher;
      Msg       : Message_Type;
      Delivered : out Boolean)
     with Pre => Is_Created (P);

   ----------------
   -- Subscriber --
   ----------------

   --  Number of registered subscribers.
   function Subscriber_Count return Natural
     with Post => Subscriber_Count'Result <= Max_Subscribers;

   --  True after Create_Subscriber has run on S.
   function Is_Registered (S : Subscriber) return Boolean;

   --  Adds S once during startup. Raises Ada.Assertions.Assertion_Error
   --  if registration is closed, capacity is exhausted, or S is registered.
   --  Capacity and duplicate checks occur together with the insertion.
   --  Other successful registrations can also increase Subscriber_Count.
   --  The registry keeps an access to S and does
   --  not copy S. Thus S must exist until the last Publish. Declare S at
   --  library level, or in the scope that contains the full run. If S
   --  goes out of scope first, the registry holds a dangling access.
   procedure Create_Subscriber (S : aliased in out Subscriber)
     with Pre  => Subscriber_Count < Max_Subscribers
                  and then not Is_Registered (S),
          Post => Is_Registered (S);

   --  Removes the oldest message from S and returns it in Msg. If S is
   --  empty, Receive blocks until a message arrives. Receive has no
   --  timeout.
   procedure Receive (S : in out Subscriber; Msg : out Message_Type)
     with Pre => Is_Registered (S);

   --  Same as Receive, but does not block. If S is empty, Success is
   --  False and Msg is not set.
   procedure Try_Receive
     (S       : in out Subscriber;
      Msg     : out Message_Type;
      Success : out Boolean)
     with Pre => Is_Registered (S);

   --  Number of messages in the queue of S.
   function Pending (S : Subscriber) return Natural;

   --  Number of messages that the queue of S has dropped since startup.
   --  This value is always 0 for a Reliable subscriber. This is the
   --  check for design rule 2.
   function Dropped (S : Subscriber) return Natural;

private

   package Ring is new Beacon.Queue (Message_Type, Queue_Depth);

   protected type Bounded_Queue (Mode : Delivery_Mode) is
      --  Push barrier: always open for Best_Effort. Open when not full
      --  for Reliable.
      entry Push (Msg : Message_Type);
      procedure Try_Push (Msg : Message_Type; Accepted : out Boolean);
      entry Pop (Msg : out Message_Type);
      procedure Try_Pop (Msg : out Message_Type; Success : out Boolean);
      function Count return Natural;
      function Drop_Count return Natural;
   private
      Q     : Ring.Queue_Type := Ring.Empty_Queue;
      Drops : Natural := 0;
   end Bounded_Queue;

   type Subscriber (Mode : Delivery_Mode) is limited record
      Queue      : Bounded_Queue (Mode);
      Registered : Boolean := False with Atomic;
   end record;

   type Publisher is limited record
      Created : Boolean := False with Atomic;
   end record;

end Beacon.Topic;
