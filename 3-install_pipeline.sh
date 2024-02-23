#!/bin/bash
. ./main.cfg

## This is hacky way of inserting things that probably will outlive trivial patch after changes
# find line number with storage:
function append_storage() {
line=$(grep -n "^storage:$" kernelci/kernelci-pipeline/config/pipeline.yaml | cut -d: -f1)
head -n $line kernelci/kernelci-pipeline/config/pipeline.yaml > tmp.yaml
# insert after line with storage: the following lines
echo "
  personal:
    storage_type: backend
    base_url: http://localhost:8080/user1/
    api_url: http://localhost:8080/" >> tmp.yaml
# insert the rest of the file
tail -n +$((line+1)) kernelci/kernelci-pipeline/config/pipeline.yaml >> tmp.yaml
mv tmp.yaml kernelci/kernelci-pipeline/config/pipeline.yaml
}

# replace in pipeline.yaml http://172.17.0.1:8001 to http://localhost:8001
sed -i 's/http:\/\/172.17.0.1:8001/http:\/\/host.docker.internal:8001/g' kernelci/kernelci-pipeline/config/pipeline.yaml

# TODO: Check if this is already done
#append_storage

# We can build on docker only
sed -i 's/name: k8s-all/name: docker/g' kernelci/kernelci-pipeline/config/pipeline.yaml

sed -i 's/env_file: .env/env_file: .env\/.env/g' kernelci/kernelci-pipeline/config/pipeline.yaml

#-      - 'data/ssh/:/home/kernelci/data/ssh'
#-      - 'data/output/:/home/kernelci/data/output'
#+      - '/root/kernelci-pipeline/data/ssh/:/home/kernelci/data/ssh'
#+      - '/root/kernelci-pipeline/data/output/:/home/kernelci/data/output'
cd kernelci/kernelci-pipeline
PIPELINE_PWD=$(pwd)
# replace lab_type: kubernetes to lab_type: docker
# This is BAD hack, but it works for now
sed -i 's/lab_type: kubernetes/lab_type: docker/g' config/pipeline.yaml

# replace data/output by $PIPELINE_PWD/data/output
# might be two variants (default and staging)
#      - '/data/kernelci-deploy-checkout/kernelci-pipeline/data/ssh/:/home/kernelci/data/ssh'
#      - '/data/kernelci-deploy-checkout/kernelci-pipeline/data/output/:/home/kernelci/data/output'
# AND
#      - 'data/ssh/:/home/kernelci/data/ssh'
#      - 'data/output/:/home/kernelci/data/output'
sed -i "s|- 'data/output/|- '\$PIPELINE_PWD'/data/output/|g" config/pipeline.yaml
sed -i "s|- 'data/ssh/|- '\$PIPELINE_PWD'/data/ssh/|g" config/pipeline.yaml
# OR
sed -i "s|- '/data/kernelci-deploy-checkout/kernelci-pipeline/data/ssh/|- '$PIPELINE_PWD/data/ssh/|g" config/pipeline.yaml
sed -i "s|- '/data/kernelci-deploy-checkout/kernelci-pipeline/data/output/|- '$PIPELINE_PWD/data/output/|g" config/pipeline.yaml

# set 777 to data/output and data/ssh (TODO: or set proper uid, kernelci is 1000?)
chmod -R 777 data
chmod 777 data/ssh
cp ../../ssh.key data/ssh/id_rsa_tarball
chown 1000:1000 data/ssh/id_rsa_tarball
chmod 600 data/ssh/id_rsa_tarball
cd ../..

#create .env
#KCI_STORAGE_CREDENTIALS=L0CALT0KEN
#KCI_API_TOKEN=
#API_TOKEN=
API_TOKEN=$(cat admin-token.txt)
echo "KCI_STORAGE_CREDENTIALS=/home/kernelci/data/ssh/id_rsa_tarball" > .env
echo "KCI_API_TOKEN=${API_TOKEN}" >> .env
echo "API_TOKEN=${API_TOKEN}" >> .env
cp .env kernelci/kernelci-pipeline/.docker-env
mv .env kernelci/kernelci-pipeline/.env
cd kernelci/kernelci-pipeline
docker-compose down
docker-compose up -d
echo "You can view now logs of containers using docker logs -f <container_id> or docker-compose logs -f in kernelci/kernelci-pipeline or kernelci/kernelci-api directories"
echo "Also you can do docker ps to see running containers, and in case of ongoing builds, you can view their logs too by docker logs -f <container_id>"
echo "You can also open API viewer at http://127.0.0.1:8001/viewer"



