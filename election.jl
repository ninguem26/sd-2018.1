using Pkg
#Pkg.add("Distributed")
using Distributed

qntWorkers = 2
Distributed.addprocs(qntWorkers)
workloads = fill(0.0, qntWorkers)
@everywhere workload = 0.0
@everywhere leaderId = 2

### Master-side functions ###

function receiveDataFromWorker(workerId, workerWorkload)
    workloads[workerId-1] = workload
end

### Worker-side functions ###

@everywhere function failureDetection()
    myId = Distributed.myid()

    qntWorkers = 2
    leaderId = 3
    candidateId = -1
    candidateWorkload = 1.0
    workloads = fill(0.0, qntWorkers)

    while true
        workload = round(rand(1)[1], digits = 1)
        @spawnat 1 receiveDataFromWorker(myid, workload)

        for pid in workers()
            if pid != myId
                @spawnat pid checkWorkload(myid, workload)
            end
        end
        sleep(2)
    end
end

@everywhere function checkWorkload(workerId, workerWorkload)
    myId = Distributed.myid()

    if workerId == leaderId && workerWorkload >= 0.8 && workload < 0.8
        println("Eleições")
    end
end

for pid in workers()
    @spawnat pid failureDetection()
end

while true
    println()
end
