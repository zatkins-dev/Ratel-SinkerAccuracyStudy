#!/usr/bin/env bash
: ${RATEL_DIR:="$HOME/project/micromorph/ratel"}
: ${NP:=6}
RATEL=$RATEL_DIR/bin/ratel-quasistatic

usage() { echo "Usage: $0 [-o <OUTPUT_DIR_BASENAME>] [-n <NUM_MPI_PROCS>] fem|mpm" 1>&2; exit 1; }

# Arguments
while getopts o:n: opt
do	
  case "$opt" in
    o)	
      OUTPUT_BASE_DIR="${OPTARG}-"
      ;;
    n)	
      NP=${OPTARG}
      ((NP > 0)) || echo "Invalid number of MPI processes" 1>&2 && usage
      ;;
    *)	
      usage
      ;;
	esac
done
shift $((OPTIND-1))

if [[ $# -ne 1 ]]; then
    usage
fi

case $1 in
    fem|mpm)  # Ok
        TEST_CASE=$1
        ;;
    *)
        # The wrong first argument.
        echo 'Expected "fem" or "mpm"' 1>&2
        usage
esac

ROOT_DIR=$(dirname $(readlink -f "$0"))
RUN_DIR=$ROOT_DIR/"$OUTPUT_BASE_DIR$TEST_CASE"
mkdir -p $RUN_DIR
MESH_DIR=$ROOT_DIR/meshes
mkdir -p $MESH_DIR
OPTIONS_FILE=$ROOT_DIR/sinker-${TEST_CASE}.yml

echo "Running sinker scaling study:"
echo "  Test case:  $TEST_CASE"
echo "  Output dir: $RUN_DIR"
echo "  MPI procs:  $NP"

for size in 5 10 15 20; do
  OUTPUT_DIR=$RUN_DIR/sinker_hex_${size}
  MESH="$MESH_DIR/sinker_hex_${size}.msh"
  if [ ! -f "$MESH" ]; then
    # generate mesh
    echo "Creating mesh with ${size}x${size}x${size} elements at $MESH"
    gmsh $ROOT_DIR/sinker_hex.geo -3 -setnumber regular 1 -setnumber nelem_in $(( size / 5 )) -o $MESH 2>&1 1>/dev/null
  fi
  ARGS="-options_file $OPTIONS_FILE -dm_plex_filename $MESH -dm_view -cdm_view \
-ts_monitor_solution cgns:$OUTPUT_DIR/solution.cgns \
-ts_monitor_diagnostic_quantities cgns:$OUTPUT_DIR/diagnostic.cgns \
-ts_monitor_strain_energy ascii:$OUTPUT_DIR/strain_energy.csv \
-ts_monitor_surface_force_per_face ascii:$OUTPUT_DIR/surface_force.csv"
  if [ "$TEST_CASE" = "mpm" ]; then
    ARGS="$ARGS -ts_monitor_swarm ascii:$OUTPUT_DIR/swarm.xmf"
  fi
  
  rm -rf $OUTPUT_DIR
  mkdir $OUTPUT_DIR
  cp $OPTIONS_FILE $OUTPUT_DIR

  echo "Running size ${size} test"
  echo "  Output dir: ${OUTPUT_DIR}"
  echo "  Arguments:  ${RATEL} $ARGS > $OUTPUT_DIR/run.stdout.txt"
  if [ "$size" != "20" ]; then
    mpirun -np $NP $RATEL $ARGS > $OUTPUT_DIR/run.stdout.txt &
  else 
    mpirun -np $NP $RATEL $ARGS > $OUTPUT_DIR/run.stdout.txt
  fi
done
