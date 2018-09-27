#=
    The following code was written by Júlio "Jooj" de Holanda, for the
    Distributed Systems course of the Computer Science course of the
    Universidade Federal de Alagoas (UFAL), taught by Professor André Lage.
=#

using Pkg
#Pkg.add("Distributed")
using Distributed

qntWorkers = 4  #Defining how many workers the system will have
Distributed.addprocs(qntWorkers)    #Creating the workers

#=

These are the distributed variables that system workers can access.
Each variable is an array and each position of each array can only be accessed
by its respective worker.

For example, positions 2 of the arrays can only be accessed by worker 2.
=#

@everywhere workloads = fill(0.0, length(workers()))    #The workloads of each worker
@everywhere leaderId = fill(2, length(workers())) #The id of the current leader
@everywhere candidateId = fill(-1, length(workers()))   #The id of the leader candidate chosen by each worker
@everywhere candidateWorkload = fill(1.0, length(workers()))    #The workload of each worker as a vote for their candidate to leader

### Master-side functions ###

#Receives the workloads of a worker and the monitored workers and displays them on the screen
function receiveDataFromWorker(message)
    println(message)
end

### Worker-side functions ###

#=
    It is looped by a worker.
    Updates the current workload of the worker, calls the function responsible
    for updating the workloads of the other workers and sends the updated loads
    to the master.
=#
@everywhere function failureDetection()
    myid = Distributed.myid()

    while true
        workloads[myid-1] = round(rand(1)[1], digits = 1)
        for pid in workers()
            if pid != myid
                @spawnat pid updateWorkloads(myid, workloads[myid-1])
            end
        end
        sleep(2)

        message = "Workload from Worker $(myid): $(workloads)"
        @spawnat 1 receiveDataFromWorker(message)
    end
end

#=
    Receives the workloads of another worker to update the load list.
    If the worker you sent is the leader and the received load was greater than
    or equal to 0.8, an election may be initiated.
=#
@everywhere function updateWorkloads(workerId, workerWorkload)
    myid = Distributed.myid()

    if candidateId[myid-1] == -1    #If an election was not started by this worker, then run the code below
    workloads[workerId-1] = workerWorkload

        #=
            If the received load came from the leader and is greater than or
            equal to 0.8 and the current worker's workload is less than 0.8
            then a new election is initiated
        =#
        if workerId == leaderId[myid-1] && workerWorkload >= 0.8 && workloads[myid-1] < 0.8
            startElection()
        end
    end
end

#=
    Updates the current leader with the id of a new leader. Also restores the
    original values ​​of the candidateId and candidateWorkloads arrays.
=#
@everywhere function updateLeader(newLeaderId)
    for pid in workers()
        leaderId[pid-1] = newLeaderId
        candidateId[pid-1] = -1
        candidateWorkload[pid-1] = 1.0
    end
end

# Defines the vote of the worker and his candidate, sending to the next worker
@everywhere function startElection()
    myid = Distributed.myid()

    candidateId[myid-1] = myid
    candidateWorkload[myid-1] = workloads[myid-1]
    nextId = myid+1

    #=
        If the worker is the last in the list of ids, then the list goes back
        to the beginning, in this case worker 2.
    =#
    if nextId > length(workers())+1
        nextId = 2
    end
    @spawnat nextId election(candidateId[myid-1], candidateWorkload[myid-1])    #Send the vote and the candidate to the next worker
end

#=
    Receive the candidate and the vote of the previous worker. If the votes are
    equal, the candidate is the worker with the most id. If not, the candidate
    will be the one with the lowest workload value (vote).
=#
@everywhere function election(workerId, workerWorkload)
    myid = Distributed.myid()
    myWorkload = workloads[myid-1]
    nextId = myid+1

    if myid == workerId # If the id is the same, then the election is over
        for pid in workers()    # Update the leader in all workers
            @spawnat pid updateLeader(myid)
        end
        println("New leader elected! Worker $(leaderId[myid-1])")
    else
        if myid != leaderId[myid-1] # Id the worker is the current leader, then skip to the next worker
            if myWorkload < workerWorkload
                candidateId[myid-1] = myid
                candidateWorkload[myid-1] = myWorkload
            elseif myWorkload > workerWorkload
                candidateId[myid-1] = workerId
                candidateWorkload[myid-1] = workerWorkload
            else
                if myid > workerId
                    candidateId[myid-1] = myid
                    candidateWorkload[myid-1] = myWorkload
                else
                    candidateId[myid-1] = workerId
                    candidateWorkload[myid-1] = workerWorkload
                end
            end
        else
            if myWorkload >= 0.8
                candidateId[myid-1] = workerId
                candidateWorkload[myid-1] = workerWorkload
            else
                candidateId[myid-1] = myid
                candidateWorkload[myid-1] = myWorkload
            end
        end

        #=
            If the worker is the last in the list of ids, then the list goes back
            to the beginning, in this case worker 2.
        =#
        if nextId > length(workers())+1
            nextId = 2
        end
        @spawnat nextId election(candidateId[myid-1], candidateWorkload[myid-1])    #Send the vote and the candidate to the next worker
    end
end

### Init system ###

for pid in workers()    # Call failureDetection in all workers
    @spawn failureDetection()
end
