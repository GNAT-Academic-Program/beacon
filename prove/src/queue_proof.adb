--  This body is not SPARK, so the prover does not see the value that
--  Any_Depth returns. A deferred constant does not hide its value: when
--  Any_Depth was a constant, GNATprove proved Any_Depth = 8.

package body Queue_Proof
  with SPARK_Mode => Off
is

   function Any_Depth return Positive is
   begin
      return 8;
   end Any_Depth;

end Queue_Proof;
