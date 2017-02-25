{{ source "common.ikt" }}

# Set up infrakit.  This assumes Docker has been installed

{{ $infrakitHome := ref "/infrakit/home" }}
mkdir -p {{$infrakitHome}}/configs
mkdir -p {{$infrakitHome}}/logs
mkdir -p {{$infrakitHome}}/plugins

{{ $dockerImage := ref "/infrakit/docker/image" }}
{{ $dockerMounts := ref "/infrakit/docker/options/mount" }}
{{ $dockerEnvs := ref "/infrakit/docker/options/env" }}

echo "alias infrakit='docker run --rm {{$dockerMounts}} {{$dockerEnvs}} {{$dockerImage}} infrakit'" >> /root/.bashrc

alias infrakit='docker run --rm {{$dockerMounts}} {{$dockerEnvs}} {{$dockerImage}} infrakit'

{{ $pluginsURL := cat (ref "/cluster/config/urlRoot") "/plugins.json" | nospace }}
{{ $groupsURL := cat (ref "/cluster/config/urlRoot") "/groups.json" | nospace }}

{{ $stackName := ref "/cluster/name" }}
{{ $metadataExportUrl := ref "/cluster/metadata/configURL" }}
{{ $metadataImage := ref "/infrakit/metadata/docker/image" }}
{{ $metadataCmd := (cat "infrakit-metadata-aws --name var --template-url" $metadataExportUrl "--stack" $stackName) }}
{{ $instanceImage := ref "/infrakit/instance/docker/image" }}
{{ $instanceCmd := (cat "infrakit-instance-aws --log 5 --namespace-tags" (cat "infrakit.scope=" $stackName | nospace)) }}


echo "Starting up infrakit"
docker run -d --restart always --name manager \
       {{$dockerMounts}} {{$dockerEnvs}} {{$dockerImage}} \
       infrakit-manager --name group  --proxy-for-group group-stateless swarm

docker run -d --restart always --name group-stateless \
       {{$dockerMounts}} {{$dockerEnvs}} {{$dockerImage}} \
       infrakit-group-default --poll-interval 5s --name group-stateless

docker run -d --restart always --name flavor-swarm \
       {{$dockerMounts}} {{$dockerEnvs}} {{$dockerImage}} \
       infrakit-flavor-swarm --log 5

echo "Starting up instance plugin"
docker run -d --restart always --name instance-plugin \
       {{$dockerMounts}} {{$dockerEnvs}} {{$instanceImage}} {{$instanceCmd}}

echo "Starting up metadata plugin"
docker run -d --restart always --name metadata \
       {{$dockerMounts}} {{$dockerEnvs}} {{$metadataImage}} {{$metadataCmd}}

# Need a bit of time for the leader to discover itself
sleep 10

# Try to commit - this is idempotent but don't error out and stop the cloud init script!
echo "Commiting to infrakit $(docker run --rm {{$dockerMounts}} {{$dockerEnvs}} {{$dockerImage}} infrakit manager commit {{$groupsURL}})"
