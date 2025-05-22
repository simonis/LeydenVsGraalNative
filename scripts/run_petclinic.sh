#!/bin/bash

if [[ ! -v JDK21_HOME ]]; then
  echo "You need to define JDK21_HOME"
  exit 1
fi
if [[ ! -v JDK24_HOME ]]; then
  echo "You need to define JDK24_HOME"
  exit 1
fi
if [[ ! -v LEYDEN_HOME ]]; then
  echo "You need to define LEYDEN_HOME"
  exit 1
fi
if [[ ! -v LEYDEN_SRC ]]; then
  echo "You need to define LEYDEN_SRC"
  exit 1
fi
# This has to point to the test/hotspot/jtreg/premain/spring-petclinic directory of Leyden premain branch
# where Petclinic was built with 'make unpack'
if [[ ! -v LEYDEN_PETCLINIC ]]; then
  echo "You need to define LEYDEN_PETCLINIC"
  exit 1
elif [[ ! -e $LEYDEN_PETCLINIC/petclinic-snapshot/target/unpacked/classes.jar ]]; then
  echo "You need to run 'make unpack' in $LEYDEN_PETCLINIC"
  exit 1
fi
LEYDEN_PETCLINIC_UNPACKED=$LEYDEN_PETCLINIC/petclinic-snapshot/target/unpacked
if [[ ! -v GRAALCE_HOME ]]; then
  echo "You need to define GRAALCE_HOME"
  exit 1
fi
if [[ ! -v GRAALEE_HOME ]]; then
  echo "You need to define GRAALEE_HOME"
  exit 1
fi

echo_and_exec() {
  if [[ -v DEBUG ]]; then
    echo "  ${@/eval/}"
  fi
  "$@"
}

if [[ -v FLAMEGRAPH && -n $FLAMEGRAPH ]]; then
  if [[ ! -x "$(command -v stackcollapse-perf.pl)" ]]; then
    echo "stackcollapse-perf.pl not in PATH. Clone https://github.com/brendangregg/FlameGraph and add it to the PATH"
    exit 1
  fi
  if [[ ! -v ASYNCPROFILER_PATH || ! -e $ASYNCPROFILER_PATH/libasyncProfiler.so ]]; then
    echo "You must define ASYNCPROFILER_PATH to point to a directory containing libasyncProfiler.so"
    exit 1
  fi
  echo_and_exec sudo sysctl kernel.perf_event_paranoid=1
  echo_and_exec sudo sysctl kernel.kptr_restrict=0
fi

OUTPUT="./build"
OUTPUT_PROFILING="${OUTPUT}-profiling"

CMDLINE="-cp ${LEYDEN_PETCLINIC_UNPACKED}/classes.jar:${LEYDEN_PETCLINIC_UNPACKED}/BOOT-INF/classes/classes.jar:${LEYDEN_PETCLINIC_UNPACKED}/BOOT-INF/lib/* -DautoQuit=true -Dspring.aot.enabled=true org.springframework.samples.petclinic.PetClinicApplication"
CMDLINE_GRAAL="--no-fallback --initialize-at-build-time=org.springframework.boot.loader.nio.file.NestedFileSystemProvider -Dspring.aot.enabled=true -cp  ${LEYDEN_PETCLINIC_UNPACKED}:${LEYDEN_PETCLINIC_UNPACKED}/BOOT-INF/classes:${LEYDEN_PETCLINIC_UNPACKED}/BOOT-INF/lib/* org.springframework.samples.petclinic.PetClinicApplication"
ARGS=""

JDK21_DEFAULT="JDK21-Default"
JDK24_DEFAULT="JDK24-Default"
JDK24_STATIC_CDS="JDK24-Static-CDS"
JDK24_DYNAMIC_CDS="JDK24-Dynamic-CDS"
JDK24_JEP483="JDK24-JEP483"
LEYDEN_PREMAIN="Leyden-Premain"
LEYDEN_PREMAIN_PRELOADONLY="Leyden-Premain-PreloadOnly"

if [[ -v BUILD && -n $BUILD ]]; then
  echo "Building .."

  echo_and_exec mkdir -p $OUTPUT

  echo ${JDK24_DEFAULT}
  echo_and_exec $JDK21_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} $CMDLINE $ARGS

  echo ${JDK24_DEFAULT}
  echo_and_exec $JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} $CMDLINE $ARGS

  echo ${JDK24_STATIC_CDS}
  echo_and_exec mkdir -p $OUTPUT/${JDK24_STATIC_CDS}
  echo_and_exec $JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -Xshare:off -XX:DumpLoadedClassList=$OUTPUT/${JDK24_STATIC_CDS}/PetClinic.classlist $CMDLINE $ARGS
  echo_and_exec $JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -Xshare:dump -XX:SharedArchiveFile=$OUTPUT/${JDK24_STATIC_CDS}/PetClinic.static.jsa -XX:SharedClassListFile=$OUTPUT/${JDK24_STATIC_CDS}/PetClinic.classlist $CMDLINE $ARGS
  echo_and_exec $JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -Xshare:on -XX:SharedArchiveFile=$OUTPUT/${JDK24_STATIC_CDS}/PetClinic.static.jsa $CMDLINE $ARGS

  echo ${JDK24_DYNAMIC_CDS}
  echo_and_exec mkdir -p $OUTPUT/${JDK24_DYNAMIC_CDS}
  echo_and_exec $JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:ArchiveClassesAtExit=$OUTPUT/${JDK24_DYNAMIC_CDS}/PetClinic.dynamic.jsa $CMDLINE $ARGS
  echo_and_exec $JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -Xshare:on -XX:SharedArchiveFile=$OUTPUT/${JDK24_DYNAMIC_CDS}/PetClinic.dynamic.jsa $CMDLINE $ARGS

  echo ${JDK24_JEP483}
  echo_and_exec mkdir -p $OUTPUT/${JDK24_JEP483}
  echo_and_exec rm -f $OUTPUT/${JDK24_JEP483}/PetClinic.aotconf $OUTPUT/${JDK24_JEP483}/PetClinic.aot
  echo_and_exec $JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=record -XX:AOTConfiguration=$OUTPUT/${JDK24_JEP483}/PetClinic.aotconf $CMDLINE $ARGS
  echo_and_exec $JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=create -XX:AOTConfiguration=$OUTPUT/${JDK24_JEP483}/PetClinic.aotconf -XX:AOTCache=$OUTPUT/${JDK24_JEP483}/PetClinic.aot $CMDLINE $ARGS
  echo_and_exec $JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=on -XX:AOTCache=$OUTPUT/${JDK24_JEP483}/PetClinic.aot $CMDLINE $ARGS

  echo_and_exec mkdir -p $OUTPUT_PROFILING/${JDK24_JEP483}
  echo_and_exec rm -f $OUTPUT_PROFILING/${JDK24_JEP483}/PetClinic.aotconf $OUTPUT_PROFILING/${JDK24_JEP483}/PetClinic.aot
  echo_and_exec $JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=record -XX:AOTConfiguration=$OUTPUT_PROFILING/${JDK24_JEP483}/PetClinic.aotconf -XX:+PreserveFramePointer $CMDLINE $ARGS
  echo_and_exec $JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=create -XX:AOTConfiguration=$OUTPUT_PROFILING/${JDK24_JEP483}/PetClinic.aotconf -XX:AOTCache=$OUTPUT_PROFILING/${JDK24_JEP483}/PetClinic.aot -XX:+PreserveFramePointer $CMDLINE $ARGS
  echo_and_exec $JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=on -XX:AOTCache=$OUTPUT_PROFILING/${JDK24_JEP483}/PetClinic.aot -XX:+PreserveFramePointer $CMDLINE $ARGS

  echo ${LEYDEN_PREMAIN}
  echo_and_exec mkdir -p $OUTPUT/${LEYDEN_PREMAIN}
  echo_and_exec rm -f $OUTPUT/${LEYDEN_PREMAIN}/PetClinic.aotconf $OUTPUT/${LEYDEN_PREMAIN}/PetClinic.aot
  echo_and_exec $LEYDEN_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=record -XX:AOTConfiguration=$OUTPUT/${LEYDEN_PREMAIN}/PetClinic.aotconfig $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=create -XX:AOTConfiguration=$OUTPUT/${LEYDEN_PREMAIN}/PetClinic.aotconfig -XX:AOTCache=$OUTPUT/${LEYDEN_PREMAIN}/PetClinic.aot $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=on -XX:AOTCache=$OUTPUT/${LEYDEN_PREMAIN}/PetClinic.aot $CMDLINE $ARGS

  echo_and_exec mkdir -p $OUTPUT_PROFILING/${LEYDEN_PREMAIN}
  echo_and_exec rm -f $OUTPUT_PROFILING/${LEYDEN_PREMAIN}/PetClinic.aotconf $OUTPUT_PROFILING/${LEYDEN_PREMAIN}/PetClinic.aot
  echo_and_exec $LEYDEN_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=record -XX:AOTConfiguration=$OUTPUT_PROFILING/${LEYDEN_PREMAIN}/PetClinic.aotconfig -XX:+PreserveFramePointer $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=create -XX:AOTConfiguration=$OUTPUT_PROFILING/${LEYDEN_PREMAIN}/PetClinic.aotconfig -XX:AOTCache=$OUTPUT_PROFILING/${LEYDEN_PREMAIN}/PetClinic.aot -XX:+PreserveFramePointer $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=on -XX:AOTCache=$OUTPUT_PROFILING/${LEYDEN_PREMAIN}/PetClinic.aot -XX:+PreserveFramePointer $CMDLINE $ARGS


  echo "Graal-CE"
  echo_and_exec mkdir -p $OUTPUT/Graal-CE
  echo_and_exec mkdir -p $OUTPUT_PROFILING/Graal-CE
  echo_and_exec $GRAALCE_HOME/bin/native-image $CMDLINE_GRAAL $OUTPUT/Graal-CE/PetClinic-Graal-CE.exe
  echo_and_exec $GRAALCE_HOME/bin/native-image -g -H:+PreserveFramePointer $CMDLINE_GRAAL $OUTPUT_PROFILING/Graal-CE/PetClinic-Graal-CE.exe

  echo "Graal-EE"
  echo_and_exec mkdir -p $OUTPUT/Graal-EE
  echo_and_exec mkdir -p $OUTPUT_PROFILING/Graal-EE
  echo_and_exec $GRAALEE_HOME/bin/native-image $CMDLINE_GRAAL $OUTPUT/Graal-EE/PetClinic-Graal-EE.exe
  echo_and_exec $GRAALEE_HOME/bin/native-image -g -H:+PreserveFramePointer $CMDLINE_GRAAL $OUTPUT_PROFILING/Graal-EE/PetClinic-Graal-EE.exe

  echo_and_exec $GRAALEE_HOME/bin/native-image --gc=G1 $CMDLINE_GRAAL $OUTPUT/Graal-EE/PetClinic-Graal-EE-G1.exe
  echo_and_exec $GRAALEE_HOME/bin/native-image -g -H:+PreserveFramePointer --gc=G1 $CMDLINE_GRAAL $OUTPUT_PROFILING/Graal-EE/PetClinic-Graal-EE-G1.exe

  echo_and_exec $GRAALEE_HOME/bin/native-image --pgo-instrument $CMDLINE_GRAAL $OUTPUT/Graal-EE/PetClinic-Graal-EE-pgo-instrumented.exe
  echo_and_exec $OUTPUT/Graal-EE/PetClinic-Graal-EE-pgo-instrumented.exe -DautoQuit=true -XX:ProfilesDumpFile=$OUTPUT/Graal-EE/default.iprof $ARGS
  echo_and_exec $GRAALEE_HOME/bin/native-image --pgo=$OUTPUT/Graal-EE/default.iprof $CMDLINE_GRAAL $OUTPUT/Graal-EE/PetClinic-Graal-EE-pgo.exe
  echo_and_exec $GRAALEE_HOME/bin/native-image -g -H:+PreserveFramePointer --pgo=$OUTPUT/Graal-EE/default.iprof $CMDLINE_GRAAL $OUTPUT_PROFILING/Graal-EE/PetClinic-Graal-EE-pgo.exe

  echo_and_exec $GRAALEE_HOME/bin/native-image --gc=G1 --pgo-instrument $CMDLINE_GRAAL $OUTPUT/Graal-EE/PetClinic-Graal-EE-G1-pgo-instrumented.exe
  echo_and_exec $OUTPUT/Graal-EE/PetClinic-Graal-EE-G1-pgo-instrumented.exe -DautoQuit=true -XX:ProfilesDumpFile=$OUTPUT/Graal-EE/g1.iprof $ARGS
  echo_and_exec $GRAALEE_HOME/bin/native-image --gc=G1 --pgo=$OUTPUT/Graal-EE/g1.iprof $CMDLINE_GRAAL $OUTPUT/Graal-EE/PetClinic-Graal-EE-G1-pgo.exe
  echo_and_exec $GRAALEE_HOME/bin/native-image -g -H:+PreserveFramePointer --gc=G1 --pgo=$OUTPUT/Graal-EE/g1.iprof $CMDLINE_GRAAL $OUTPUT_PROFILING/Graal-EE/PetClinic-Graal-EE-G1-pgo.exe

fi # if [[ -v BUILD ]]

modes=(
  ${JDK21_DEFAULT}
  ${JDK24_DEFAULT}
  ${JDK24_STATIC_CDS}
  ${JDK24_DYNAMIC_CDS}
  ${JDK24_JEP483}
  ${LEYDEN_PREMAIN}
  ${LEYDEN_PREMAIN_PRELOADONLY}
  "Graal-CE"
  "Graal-EE"
  "Graal-EE-G1"
  "Graal-EE-PGO"
  "Graal-EE-G1-PGO"
)

params=(
  "$JDK21_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} $CMDLINE"
  "$JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} $CMDLINE"
  "$JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -Xshare:on -XX:SharedArchiveFile=$OUTPUT/${JDK24_STATIC_CDS}/PetClinic.static.jsa $CMDLINE"
  "$JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -Xshare:on -XX:SharedArchiveFile=$OUTPUT/${JDK24_DYNAMIC_CDS}/PetClinic.dynamic.jsa $CMDLINE"
  "$JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=on -XX:AOTCache=$OUTPUT/${JDK24_JEP483}/PetClinic.aot $CMDLINE"
  "$LEYDEN_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=on -XX:AOTCache=$OUTPUT/${LEYDEN_PREMAIN}/PetClinic.aot $CMDLINE"
  "$LEYDEN_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=on -XX:AOTCache=$OUTPUT/${LEYDEN_PREMAIN}/PetClinic.aot -XX:+UnlockExperimentalVMOptions -XX:+PreloadOnly $CMDLINE"
  "$OUTPUT/Graal-CE/PetClinic-Graal-CE.exe ${HEAP_ARGS} -DautoQuit=true"
  "$OUTPUT/Graal-EE/PetClinic-Graal-EE.exe ${HEAP_ARGS} -DautoQuit=true"
  "$OUTPUT/Graal-EE/PetClinic-Graal-EE-G1.exe ${HEAP_ARGS} -DautoQuit=true"
  "$OUTPUT/Graal-EE/PetClinic-Graal-EE-pgo.exe ${HEAP_ARGS} -DautoQuit=true"
  "$OUTPUT/Graal-EE/PetClinic-Graal-EE-G1-pgo.exe ${HEAP_ARGS} -DautoQuit=true"
)

params_profiling=(
  "$JDK21_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} $CMDLINE"
  "$JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} $CMDLINE"
  "$JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -Xshare:on -XX:SharedArchiveFile=$OUTPUT/${JDK24_STATIC_CDS}/PetClinic.static.jsa $CMDLINE"
  "$JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -Xshare:on -XX:SharedArchiveFile=$OUTPUT/${JDK24_DYNAMIC_CDS}/PetClinic.dynamic.jsa $CMDLINE"
  "$JDK24_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=on -XX:AOTCache=$OUTPUT/${JDK24_JEP483}/PetClinic.aot $CMDLINE"
  "$LEYDEN_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=on -XX:AOTCache=$OUTPUT_PROFILING/${LEYDEN_PREMAIN}/PetClinic.aot $CMDLINE"
  "$LEYDEN_HOME/bin/java ${GC_ARG} ${HEAP_ARGS} -XX:AOTMode=on -XX:AOTCache=$OUTPUT_PROFILING/${LEYDEN_PREMAIN}/PetClinic.aot -XX:+UnlockExperimentalVMOptions -XX:+PreloadOnly $CMDLINE"
  "$OUTPUT_PROFILING/Graal-CE/PetClinic-Graal-CE.exe ${HEAP_ARGS} -DautoQuit=true"
  "$OUTPUT_PROFILING/Graal-EE/PetClinic-Graal-EE.exe ${HEAP_ARGS} -DautoQuit=true"
  "$OUTPUT_PROFILING/Graal-EE/PetClinic-Graal-EE-G1.exe ${HEAP_ARGS} -DautoQuit=true"
  "$OUTPUT_PROFILING/Graal-EE/PetClinic-Graal-EE-pgo.exe ${HEAP_ARGS} -DautoQuit=true"
  "$OUTPUT_PROFILING/Graal-EE/PetClinic-Graal-EE-G1-pgo.exe ${HEAP_ARGS} -DautoQuit=true"
)

DATADIR=$OUTPUT/data
echo_and_exec mkdir -p $DATADIR
TIMESTAMP=`date +%G-%m-%d-%H-%M`

if [[ -v TIME && -n $TIME ]]; then
  for i in ${!modes[@]}; do
    echo_and_exec ${TASKSET} hyperfine -w 3 -r 20 -L iterations 1 -u millisecond --style full --export-csv $DATADIR/${modes[$i]}-$TIMESTAMP.csv -n ${modes[$i]} "${params[$i]}"
  done
fi

if [[ -v MEMORY && -n $MEMORY ]]; then
  for i in ${!modes[@]}; do
    for iterations in "1"; do
      for j in {1..10}; do
        echo_and_exec ${TASKSET} /usr/bin/time -o $DATADIR/${modes[$i]}-$iterations-$TIMESTAMP.rss -a -f %M ${params[$i]}
      done
    done
  done
fi

if [[ -v FLAMEGRAPH && -n $FLAMEGRAPH ]]; then
  perf=(
    "10000"
    "1000"
    "100"
  )
  async=(
    "100000"
    "1000000"
    "10000000"
  )
  iters=(
    "1"
  )
  for i in ${!modes[@]}; do
    for j in ${!iters[@]}; do
      iterations=${iters[$j]}
      if [[ ${modes[$i]} =~ "Graal" ]]; then
        echo_and_exec perf record -F ${perf[$j]} -g --call-graph fp -o $DATADIR/${modes[$i]}-$iterations-$TIMESTAMP.data ${params_profiling[$i]} $iterations
      else
        echo_and_exec perf record -F ${perf[$j]} -g --call-graph fp -o $DATADIR/${modes[$i]}-$iterations-$TIMESTAMP.data ${params_profiling[$i]/"java"/"java -XX:+PreserveFramePointer -XX:+UnlockDiagnosticVMOptions -XX:+DumpPerfMapAtExit"} $iterations
      fi
      echo_and_exec eval "perf script -i $DATADIR/${modes[$i]}-$iterations-$TIMESTAMP.data | stackcollapse-perf.pl --tid | flamegraph.pl --title=\"PetClinic (${modes[$i]})\" --colors=java --inverted - > $DATADIR/${modes[$i]}-$iterations-$TIMESTAMP.svg"
      echo_and_exec rm $DATADIR/${modes[$i]}-$iterations-$TIMESTAMP.data
      if [[ ! ${modes[$i]} =~ "Graal" ]]; then
        echo_and_exec eval ${params_profiling[$i]/"java"/"java -agentpath:$ASYNCPROFILER_PATH/libasyncProfiler.so=start,event=cpu,interval=${async[$j]},flamegraph,threads,inverted,cstack=vm,title='PetClinic (${modes[$i]})',file=$DATADIR/${modes[$i]}-$iterations-$TIMESTAMP.html"} $iterations
      fi
    done
  done
fi
