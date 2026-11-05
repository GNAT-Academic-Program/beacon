--  Beacon.Queue with a Depth that the prover does not know.
--  See Queue_Proof.

pragma SPARK_Mode (On);

with Beacon.Queue;

package Queue_Proof.Any is new Beacon.Queue
  (Element_Type => Integer, Depth => Queue_Proof.Any_Depth);
