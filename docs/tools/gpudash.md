# GPU Dashboard

The `gpudash` command generates a text-based dashboard of the GPU utilization across a cluster in the form of a 2-dimensional grid. Each cell displays the utilization from 0-100% along with the username associated with each allocated GPU. Cells are colored according to their utilization values making it easy to identify jobs with low or high GPU utilization. The `gpudash` command can also be used to check for available GPUs.

By default, the dashboard has seven columns and a number of rows equal to the number of GPUs on the cluster. Each column is evenly spaced in time by N minutes. We find a good choice is N=10 minutes which leads to data being shown over an hour. The `cron` utility can be used to achieve this. The rows are labeled by the node name and the GPU index while the columns are labeled by time.

The `gpudash` command works by making the three queries to the Prometheus server every N minutes. A Python script is used to extract the information from the three generated JSON files and append this data to the files read by `gpudash`. The `UID` for each user is matched with its corresponding username. The `jobid` is not required but it can be useful for troubleshooting.

Nodes that are down, or in a state which makes them unavailable, are not shown in the dashboard. Labels can be added to mark reserved nodes or special-purpose nodes.


## Installation

The installation requirements for `gpudash` are Python 3.6+ and version 1.17+ of the Python `blessed` package which is used for creating colored text and backgrounds. The Python code and instructions are available at <a href="https://github.com/PrincetonUniversity/gpudash" target="_blank">https://github.com/PrincetonUniversity/gpudash</a>.
