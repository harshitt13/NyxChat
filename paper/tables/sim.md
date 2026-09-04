| Strategy | Nodes | Delivery ratio | Mean latency (s) | p95 latency (s) | Transmissions per delivered msg | Mean stored packets per node |
|---|---|---|---|---|---|---|
| Direct contact only | 10 | 0.47 | 631 | 1336 | 50 | 4.9 |
| Direct contact only | 20 | 0.54 | 761 | 1394 | 142 | 2.5 |
| Direct contact only | 40 | 0.52 | 652 | 1419 | 287 | 1.2 |
| Direct contact only | 80 | 0.46 | 688 | 1412 | 465 | 0.6 |
| Spray-and-Wait (L=3), NyxChat default | 10 | 0.68 | 698 | 1333 | 38 | 18.2 |
| Spray-and-Wait (L=3), NyxChat default | 20 | 0.91 | 642 | 1184 | 110 | 24.4 |
| Spray-and-Wait (L=3), NyxChat default | 40 | 0.96 | 502 | 1129 | 350 | 30.5 |
| Spray-and-Wait (L=3), NyxChat default | 80 | 0.99 | 434 | 948 | 980 | 32.4 |
| Epidemic flooding | 10 | 0.90 | 603 | 1152 | 324 | 25.3 |
| Epidemic flooding | 20 | 1.00 | 479 | 932 | 1654 | 32.0 |
| Epidemic flooding | 40 | 1.00 | 272 | 647 | 7417 | 37.3 |
| Epidemic flooding | 80 | 1.00 | 191 | 484 | 25237 | 33.9 |
Table: Mesh delivery in a 600 x 600 m arena with 40 m radio range, random-waypoint mobility (0.5-2 m/s), 60 messages injected during the first 10 minutes of a 30-minute run; mean over 5 seeds per cell.
