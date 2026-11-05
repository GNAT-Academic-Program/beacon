--  Beacon.Queue with Depth = 1. Ring_Index has one value, so Head, Tail
--  and the result of Next are always 0. See Queue_Proof.

pragma SPARK_Mode (On);

with Beacon.Queue;

package Queue_Proof.One is new Beacon.Queue (Element_Type => Integer, Depth => 1);
