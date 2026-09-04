| Strategy | Nodes | Delivery ratio | Mean latency (s) | p95 latency (s) | Transmissions per delivered msg | Mean stored packets per node |
|---|---|---|---|---|---|---|
| Direct contact only | 10 | 0.48 | 653 | 1392 | 50 | 4.9 |
| Direct contact only | 20 | 0.54 | 750 | 1395 | 142 | 2.5 |
| Direct contact only | 40 | 0.52 | 653 | 1419 | 288 | 1.2 |
| Direct contact only | 80 | 0.46 | 688 | 1412 | 465 | 0.6 |
| Spray-and-Wait (L=3), NyxChat default | 10 | 0.72 | 708 | 1343 | 35 | 18.4 |
| Spray-and-Wait (L=3), NyxChat default | 20 | 0.88 | 682 | 1311 | 113 | 24.5 |
| Spray-and-Wait (L=3), NyxChat default | 40 | 0.96 | 491 | 1111 | 351 | 30.4 |
| Spray-and-Wait (L=3), NyxChat default | 80 | 0.98 | 425 | 1024 | 994 | 32.4 |
| Epidemic flooding | 10 | 0.90 | 603 | 1152 | 324 | 25.3 |
| Epidemic flooding | 20 | 1.00 | 479 | 932 | 1654 | 32.0 |
| Epidemic flooding | 40 | 1.00 | 272 | 647 | 7417 | 37.3 |
| Epidemic flooding | 80 | 1.00 | 191 | 484 | 25237 | 33.9 |
Table: Mesh delivery in a 600 x 600 m arena with 40 m radio range, random-waypoint mobility (0.5-2 m/s), 60 messages injected during the first 10 minutes of a 30-minute run; mean over 5 seeds per cell.
