#!/bin/bash
sytemctl start consul
nomad job run /etc/nomad.d/jobs/fabio.hcl
nomad job run /etc/nomad.d/jobs/countdash.hcl