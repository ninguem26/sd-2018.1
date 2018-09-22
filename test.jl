using Pkg
#Pkg.add("Distributed")
using Distributed

qnt_workers = 2
Distributed.addprocs(qnt_workers)

for i = 2:(qnt_workers + 1)
    @spawn failureDetection()
end

### Master-side functions ###

function receiveDataFromWorker(message)
    println(message)
end

### Worker-side functions ###

@everywhere function failureDetection()
    while true
        sleep(2)

        message = "Workload from Worker $(Distributed.myid()): [0.4,0.9,0.7]"
        @spawnat 1 receiveDataFromWorker(message)
    end
end
