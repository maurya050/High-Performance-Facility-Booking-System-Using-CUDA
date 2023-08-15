# High-Performance-Facility-Booking-System-Using-CUDA
Design a high-performance reservation processing system that harnesses the computational power of CUDA GPU cores, resulting in accelerated and efficient request handling


# Facility Booking System
The Facility Booking Application is designed to manage and allocate facility rooms in N computer centers to users' requests. Each facility room provides specific facilities such as supercomputers, mainframes, workstations, and personal computers, with varying capacities.

## Goal:
The goal of this project is to efficiently handle user requests for booking facility rooms across multiple computer centers. Users can request to book facility rooms for a specific duration (number of time slots) during the day. The application must parallelize the processing of these requests using GPU cores for optimal performance.

### User Requests(Users provide the following details):
- Computer center number
- Facility room number
- Starting time slot for facility usage
- Number of consecutive time slots to reserve

### Processing:
* The application processes multiple user requests concurrently using GPU cores to achieve high throughput.
* If the requested slots are available for the specified facility room, the request is marked as successful. Otherwise, it is considered a failed request.

## Result: 
*At the end of processing all requests, the application provides the following information:*
- Total number of successful requests.
- Total number of failed requests.
- Breakdown of successful and failed requests for each computer center.
