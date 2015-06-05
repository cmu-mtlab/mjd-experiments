# Borrowed from Jon Clark's configuration

# TODO: This is evil, we shouldn't need to copy-paste
# Doesn't specify vmem
submitter sdsc_normal :: walltime
                        :: COMMANDS
                        :: TASK REALIZATION CONFIGURATION {
  action run {
    wrapper="ducttape_job.sh"

    echo "#PBS -S /bin/bash" >> $wrapper
    echo "#PBS -q normal" >> $wrapper
    if [[ $(hostname) =~ "gordon" ]]; then
      echo "#PBS -l nodes=1:ppn=16:native:flash" >> $wrapper
    elif [[ $(hostname) =~ "gcn-" ]]; then
      echo "#PBS -l nodes=1:ppn=16:native:flash" >> $wrapper
    else
      echo "#PBS -l nodes=1:ppn=32" >> $wrapper
    fi
    echo "#PBS -l walltime=$walltime" >> $wrapper
    echo "#PBS -j oe" >> $wrapper
    echo "#PBS -o localhost:$PWD/ducttape_job_out.txt" >> $wrapper
    echo "#PBS -N $(echo $CONFIGURATION/$TASK/$REALIZATION | head -c 200)" >> $wrapper

    echo "#PBS -m bea" >> $wrapper
    echo "#PBS -V" >> $wrapper # As of January 2014, this appears to no longer be working correctly -- use declare -p instead

    # Since PBS -V doesn't seem to be capturing the environment for us, we'll do it ourselves...
    # Do this before set -e since declare can give strange return codes
    #
    # The filters are mainly for cases where we submit jobs from a compute node:
    # There, we will already have defined many environment variables that are typically
    # only seen inside jobs. So we need to remove them so that we don't overwrite each tasks's
    # variables with the values from the other compute node that submitted the job
    declare -p \
      | egrep -v "declare -[^ ]*r" \
      | fgrep -v PBS \
      | fgrep -v LOCAL_SCRATCH \
      | fgrep -v PR_ \
      | fgrep -v INTELHOME \
      | fgrep -v INTEL_LICENSE_FILE \
      | fgrep -v IPPROOT \
      | fgrep -v INCLUDE \
      | fgrep -v LIBRARY_PATH \
      | fgrep -v LOCAL_SCRATCH \
      | fgrep -v CPATH \
      | fgrep -v FPATH \
      | fgrep -v ENVIRONMENT \
      | fgrep -v MKL_ROOT \
      | fgrep -v OASIS_SCRATCH \
      | fgrep -v TBBROOT \
      > $wrapper.env
    echo "source $PWD/$wrapper.env" >> $wrapper

    # Bash flags aren't necessarily passed into the scheduler
    # so we must initialize them
    echo "set -e # stop on errors" >> $wrapper
    echo "set -o pipefail # stop on pipeline errors" >> $wrapper
    echo "set -u # stop on undeclared variables" >> $wrapper
    echo "set -x # show each command as it is executed" >> $wrapper

    # The current working directory will also be changed
    echo "cd $PWD" >> $wrapper
    echo >> $wrapper
 
    # NOTE: Commands will be literally substituted here by ducttape, not bash
    echo "$COMMANDS" >> $wrapper



    # XXX
    #sec=$(($RANDOM % 30))
    #echo >&2 "Submitting in $sec sec..."
    #sleep $sec # Don't spam qsub


    qsub $wrapper > ducttape_sdsc_jobid.txt
    sleep 10 # Give the scheduler some time to begin showing the job in qstat

    # TODO: XXX: FIXME: implement new submitter framework that handles Torque better
    UGLY_HARDCODED_DUCTTAPE_DIR=/home/mdenkows/ducttape/builtins
    # TODO: Move this into new and improved submitter framework, once it's implemented
    $UGLY_HARDCODED_DUCTTAPE_DIR/pbs-wait-for-job.sh \
        $(cat ducttape_sdsc_jobid.txt) \
        ducttape_job_out.txt \
        ducttape_job.info
  }
}

# TODO: This is evil, we shouldn't need to copy-paste
submitter sdsc_shared :: walltime cpus vmem
                        :: COMMANDS
                        :: TASK REALIZATION CONFIGURATION {
  action run {
    wrapper="ducttape_job.sh"

    echo "#PBS -S /bin/bash" >> $wrapper

    if [[ $(hostname) =~ "gordon" || $(hostname) =~ "gcn"* ]]; then
      # Gordon doesn't support shared node access, so just request a whole node
      echo "#PBS -q normal" >> $wrapper
      echo "#PBS -l nodes=1:ppn=16:native:flash" >> $wrapper
    else
      echo "#PBS -q shared" >> $wrapper
      echo "#PBS -l nodes=1:ppn=$cpus" >> $wrapper
      echo "#PBS -l vmem=$vmem" >> $wrapper
    fi

    # Specify more than half the memory so that no 2 jobs can get scheduled on the same machine
    echo "#PBS -l mem=40g" >> $wrapper
    echo "#PBS -l walltime=$walltime" >> $wrapper
    echo "#PBS -j oe" >> $wrapper
    echo "#PBS -o localhost:$PWD/ducttape_job_out.txt" >> $wrapper
    echo "#PBS -N $(echo $CONFIGURATION/$TASK/$REALIZATION | head -c 200)" >> $wrapper

    echo "#PBS -m bea" >> $wrapper
    echo "#PBS -V" >> $wrapper # As of January 2014, this appears to no longer be working correctly -- use declare -p instead

    # Since PBS -V doesn't seem to be capturing the environment for us, we'll do it ourselves...
    # Do this before set -e since declare can give strange return codes
    declare -p | egrep -v "declare -[^ ]*r" | fgrep -v PBS > $wrapper.env
    echo "source $PWD/$wrapper.env" >> $wrapper

    # Bash flags aren't necessarily passed into the scheduler
    # so we must initialize them
    echo "set -e # stop on errors" >> $wrapper
    echo "set -o pipefail # stop on pipeline errors" >> $wrapper
    echo "set -u # stop on undeclared variables" >> $wrapper
    echo "set -x # show each command as it is executed" >> $wrapper

    # The current working directory will also be changed
    echo "cd $PWD" >> $wrapper
    echo >> $wrapper

    # NOTE: Commands will be literally substituted here by ducttape, not bash
    echo "$COMMANDS" >> $wrapper

    # XXX
    sec=$(($RANDOM % 30))
    echo >&2 "Submitting in $sec sec..."
    sleep $sec # Don't spam qsub

    qsub $wrapper > ducttape_sdsc_jobid.txt
    sleep 10 # Give the scheduler some time to begin showing the job in qstat

    # TODO: XXX: FIXME: implement new submitter framework that handles Torque better
    UGLY_HARDCODED_DUCTTAPE_DIR=/home/mdenkows/ducttape/builtins
    # TODO: Move this into new and improved submitter framework, once it's implemented
    $UGLY_HARDCODED_DUCTTAPE_DIR/pbs-wait-for-job.sh \
        $(cat ducttape_sdsc_jobid.txt) \
        ducttape_job_out.txt \
        ducttape_job.info
  }
}
