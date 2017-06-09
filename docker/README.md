# Docker swarm instructions for imaginary

on the manger node:

    docker swarm init --autolock

it will return a command to run on worker nodes similar to this:

    Swarm initialized: current node (v2l9dzx4qimn4mf06pw3pzo2f) is now a manager.

    To add a worker to this swarm, run the following command:

        docker swarm join \
        --token SWMTKN-1-5kwbvkm9qq0t04zkqmmewtg401rcgmmghx5w7tykl8ajzguvta-6swrd16kpya30tn1d550ytouk \
        10.162.26.48:2377

    To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.

    To unlock a swarm manager after it restarts, run the `docker swarm unlock`
    command and provide the following key:

        SWMKEY-1-D40kc4/bTcRZspAtwuDC+jz9HBwnclqy2CRURkzW+G4

    Please remember to store this key in a password manager, since without it you
    will not be able to restart the manager.

Then on the master run:

    docker stack deploy --compose-file docker-stack.yml imaginary


# Architecture

there are 3 docker containers at minimum.

* frontend_cache: varnish cache that sits between CDN and Imaginary (port 80 - exposed outside) [single instance - Deployes to master node]
* worker: [Scalable] imaginary docker container (port 9000 - should not expose outside of network) 
* backend_cache: varnish cache that sits between the imaginary worker and in front of Azure (port 81 - should not expose outside of network) [single instance - Deployes to other than master node]

The frontend_cache and backend_cache sit on different internal networks called:

* frontend
* backend
