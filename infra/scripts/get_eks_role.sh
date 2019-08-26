#!/usr/bin/bash


echo "{"
echo '"role_name": "'`kubectl -n kube-system describe configmap aws-auth | grep 'rolearn:' | cut -f2 -d'/'`'"'
echo "}"
