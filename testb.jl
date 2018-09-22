using Pkg
#Pkg.add("Distributed")
using Distributed

@everywhere qnt_workers = 3
Distributed.addprocs(qnt_workers)

@everywhere leaderId = 2

### Master-side functions ###

function receiveDataFromWorker(message)
    println(message)
end

### Worker-side functions ###

@everywhere qnt_workers = 3
@everywhere workloads = fill(-1.0, qnt_workers)

@everywhere function failureDetection()
    myid = Distributed.myid()

    while true
        workloads[myid-1] = round(rand(1)[1], digits = 1)
        for i=2:qnt_workers+1
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
    #println("Worker: $(workerId) | Leader: $(leaderId)")
    if workerId == leaderId && workerWorkload >= 0.8
        println("ELEIÇÕEEEEEEES!!! Leader Workload: $(workerWorkload)")
    else
        workloads[workerId-1] = workerWorkload
    end
end

### Init system ###

for i = 2:(qnt_workers + 1)
    @spawn failureDetection()
end
