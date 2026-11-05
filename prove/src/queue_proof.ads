--  Queue_Proof: parent of the SPARK instances of Beacon.Queue.
--
--  GNATprove analyzes a generic only through an instance in SPARK code.
--  The child units of this package are these instances:
--
--     Queue_Proof.Any   Depth => Any_Depth
--     Queue_Proof.One   Depth => 1, the smallest ring
--
--  A proof of an instance with a static Depth holds only for that value
--  of Depth. The proof of Queue_Proof.Any holds for each value of Depth.

package Queue_Proof
  with SPARK_Mode => On
is

   --  Returns a Depth whose value the prover does not know. The prover
   --  knows only that the result is in Positive.
   function Any_Depth return Positive
     with Global => null;

end Queue_Proof;
