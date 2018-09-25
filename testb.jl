using Pkg
#Pkg.add("Distributed")
using Distributed

@everywhere qntWorkers = 3
Distributed.addprocs(qntWorkers)

@everywhere qntWorkers = 3
@everywhere workloads = fill(0.0, qntWorkers)
@everywhere leaderId = fill(3, qntWorkers)
@everywhere candidateId = fill(-1, qntWorkers)
@everywhere candidateWorkload = fill(1.0, qntWorkers)

### Master-side functions ###

function receiveDataFromWorker(message)
    println(message)
end

### Worker-side functions ###

@everywhere function failureDetection()
    myid = Distributed.myid()

    while true
        workloads[myid-1] = round(rand(1)[1], digits = 1)
        for i=2:qntWorkers+1
            if i != myid
                @spawnat i updateWorkloads(myid, workloads[myid-1])
            end
        end
        sleep(2)

        message = "Workload from Worker $(myid): $(workloads)"
        @spawnat 1 receiveDataFromWorker(message)
    end
end

@everywhere function updateWorkloads(workerId, workerWorkload)
    myid = Distributed.myid()

    if candidateId[myid-1] == -1
    workloads[workerId-1] = workerWorkload

        if workerId == leaderId[myid-1] && workerWorkload >= 0.8 && workloads[myid-1] < 0.8
            startElection()
        end
    end
end

@everywhere function startElection()
    myid = Distributed.myid()

    println("Elections started")
    candidateId[myid-1] = myid
    candidateWorkload[myid-1] = workloads[myid-1]
    nextId = myid+1

    if nextId > qntWorkers+1
        nextId = 2
    end
    if nextId == leaderId[myid-1]
        nextId += 1
        if nextId > qntWorkers+1
            nextId = 2
        end
    end

    @spawnat nextId election(candidateId[myid-1], candidateWorkload[myid-1])
end

@everywhere function updateLeader(newLeaderId)
    for pid in workers()
        leaderId[pid-1] = newLeaderId
        candidateId[pid-1] = -1
        candidateWorkload[pid-1] = 1.0
    end
end

@everywhere function election(workerId, workerWorkload)
    myid = Distributed.myid()
    myWorkload = workloads[myid-1]
    nextId = myid+1

    println("Eleição chegou ao nó $(myid)")

    if myid == workerId
        for pid in workers()
            @spawnat pid updateLeader(myid)
        end
        println("New leader elected! Worker $(leaderId[myid-1])")
    else
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

        if nextId > qntWorkers+1
            nextId = 2
        end
        if nextId == leaderId[myid-1]
            nextId += 1
            if nextId > qntWorkers+1
                nextId = 2
            end
        end

        @spawnat nextId election(candidateId[myid-1], candidateWorkload[myid-1])
    end
end

### Init system ###

for i = 2:(qntWorkers + 1)
    @spawn failureDetection()
end
