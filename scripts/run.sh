#!/bin/bash

if [[ ! -v LEYDEN_HOME ]]; then
  echo "You need to define LEYDEN_HOME"
  exit 1
fi
if [[ ! -v LEYDEN_SRC ]]; then
  echo "You need to define LEYDEN_SRC"
  exit 1
fi
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

OUTPUT="./build"
OUTPUT_PROFILING="${OUTPUT}-profiling"

CMDLINE="-cp $OUTPUT/JavacBenchApp.jar JavacBenchApp"
ARGS="90"

if [[ -v BUILD ]]; then
  echo "Building .."

  echo_and_exec mkdir -p $OUTPUT
  echo_and_exec $LEYDEN_HOME/bin/javac --release 21 -d $OUTPUT/JavacBenchApp/ $LEYDEN_SRC/test/hotspot/jtreg/runtime/cds/appcds/applications/JavacBenchApp.java
  echo_and_exec $LEYDEN_HOME/bin/jar cf $OUTPUT/JavacBenchApp.jar -C $OUTPUT/JavacBenchApp .

  echo "Static-CDS"
  echo_and_exec mkdir -p $OUTPUT/Static-CDS
  echo_and_exec $LEYDEN_HOME/bin/java -Xshare:off -XX:DumpLoadedClassList=$OUTPUT/Static-CDS/JavacBench.classlist $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java -Xshare:dump -XX:SharedArchiveFile=$OUTPUT/Static-CDS/JavacBench.static.jsa -XX:SharedClassListFile=$OUTPUT/Static-CDS/JavacBench.classlist $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java -Xshare:on -XX:SharedArchiveFile=$OUTPUT/Static-CDS/JavacBench.static.jsa $CMDLINE $ARGS

  echo "Dynamic-CDS"
  echo_and_exec mkdir -p $OUTPUT/Dynamic-CDS
  echo_and_exec $LEYDEN_HOME/bin/java -XX:ArchiveClassesAtExit=$OUTPUT/Dynamic-CDS/JavacBench.dynamic.jsa $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java -Xshare:on -XX:SharedArchiveFile=$OUTPUT/Dynamic-CDS/JavacBench.dynamic.jsa $CMDLINE $ARGS

  echo "Leyden"
  echo_and_exec mkdir -p $OUTPUT/Leyden
  echo_and_exec rm -f $OUTPUT/Leyden/JavacBench.cds
  echo_and_exec $LEYDEN_HOME/bin/java -XX:+AOTClassLinking -XX:+ArchiveDynamicProxies -XX:CacheDataStore=$OUTPUT/Leyden/JavacBench.cds $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java -XX:CacheDataStore=$OUTPUT/Leyden/JavacBench.cds $CMDLINE $ARGS

  echo_and_exec mkdir -p $OUTPUT_PROFILING/Leyden
  echo_and_exec rm -f $OUTPUT_PROFILING/Leyden/JavacBench.cds
  echo_and_exec $LEYDEN_HOME/bin/java -XX:+AOTClassLinking -XX:+ArchiveDynamicProxies -XX:CacheDataStore=$OUTPUT_PROFILING/Leyden/JavacBench.cds -XX:+PreserveFramePointer $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java -XX:CacheDataStore=$OUTPUT_PROFILING/Leyden/JavacBench.cds -XX:+PreserveFramePointer $CMDLINE $ARGS

  echo "AOT"
  echo_and_exec mkdir -p $OUTPUT/AOT
  echo_and_exec $LEYDEN_HOME/bin/java -XX:AOTMode=record -XX:AOTConfiguration=$OUTPUT/AOT/JavacBench.aotconfig $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java -XX:AOTMode=create -XX:AOTConfiguration=$OUTPUT/AOT/JavacBench.aotconfig -XX:AOTCache=$OUTPUT/AOT/JavacBench.aot $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java -XX:AOTMode=on -XX:AOTCache=$OUTPUT/AOT/JavacBench.aot $CMDLINE $ARGS

  echo_and_exec mkdir -p $OUTPUT_PROFILING/AOT
  echo_and_exec $LEYDEN_HOME/bin/java -XX:AOTMode=record -XX:AOTConfiguration=$OUTPUT_PROFILING/AOT/JavacBench.aotconfig -XX:+PreserveFramePointer $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java -XX:AOTMode=create -XX:AOTConfiguration=$OUTPUT_PROFILING/AOT/JavacBench.aotconfig -XX:AOTCache=$OUTPUT_PROFILING/AOT/JavacBench.aot -XX:+PreserveFramePointer $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java -XX:AOTMode=on -XX:AOTCache=$OUTPUT_PROFILING/AOT/JavacBench.aot -XX:+PreserveFramePointer $CMDLINE $ARGS

  echo "Graal-CE"
  echo_and_exec mkdir -p $OUTPUT/Graal-CE
  echo_and_exec mkdir -p $OUTPUT_PROFILING/Graal-CE
  echo_and_exec $GRAALCE_HOME/bin/java -agentlib:native-image-agent=config-output-dir=$OUTPUT/Graal-CE/libnative-image-agent-class,experimental-class-define-support $CMDLINE $ARGS
  echo_and_exec mkdir -p $OUTPUT/Graal-CE/libnative-image-agent-class/META-INF/native-image
  echo_and_exec cp -rf $OUTPUT/Graal-CE/libnative-image-agent-class/agent-extracted-predefined-classes $OUTPUT/Graal-CE/libnative-image-agent-class/*.json $OUTPUT/Graal-CE/libnative-image-agent-class/META-INF/native-image/
  echo_and_exec $GRAALCE_HOME/bin/native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem -cp $OUTPUT/Graal-CE/libnative-image-agent-class $CMDLINE $OUTPUT/Graal-CE/JavacBenchApp-Graal-CE.exe

  echo_and_exec $GRAALCE_HOME/bin/native-image -g -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem -H:+PreserveFramePointer -cp $OUTPUT/Graal-CE/libnative-image-agent-class $CMDLINE $OUTPUT_PROFILING/Graal-CE/JavacBenchApp-Graal-CE.exe

  echo "Graal-EE"
  echo_and_exec mkdir -p $OUTPUT/Graal-EE
  echo_and_exec mkdir -p $OUTPUT_PROFILING/Graal-EE
  echo_and_exec $GRAALEE_HOME/bin/java -agentlib:native-image-agent=config-output-dir=$OUTPUT/Graal-EE/libnative-image-agent-class,experimental-class-define-support $CMDLINE $ARGS
  echo_and_exec mkdir -p $OUTPUT/Graal-EE/libnative-image-agent-class/META-INF/native-image
  echo_and_exec cp -rf $OUTPUT/Graal-EE/libnative-image-agent-class/agent-extracted-predefined-classes $OUTPUT/Graal-EE/libnative-image-agent-class/*.json $OUTPUT/Graal-EE/libnative-image-agent-class/META-INF/native-image/
  echo_and_exec $GRAALEE_HOME/bin/native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem -cp $OUTPUT/Graal-EE/libnative-image-agent-class $CMDLINE $OUTPUT/Graal-EE/JavacBenchApp-Graal-EE.exe
  echo_and_exec $GRAALEE_HOME/bin/native-image -g -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem -H:+PreserveFramePointer -cp $OUTPUT/Graal-EE/libnative-image-agent-class $CMDLINE $OUTPUT_PROFILING/Graal-EE/JavacBenchApp-Graal-EE.exe

  echo_and_exec $GRAALEE_HOME/bin/native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem --gc=G1 -cp $OUTPUT/Graal-EE/libnative-image-agent-class $CMDLINE $OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-G1.exe
  echo_and_exec $GRAALEE_HOME/bin/native-image -g -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem -H:+PreserveFramePointer --gc=G1 -cp $OUTPUT/Graal-EE/libnative-image-agent-class $CMDLINE $OUTPUT_PROFILING/Graal-EE/JavacBenchApp-Graal-EE-G1.exe

  echo_and_exec $GRAALEE_HOME/bin/native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem --pgo-instrument -cp $OUTPUT/Graal-EE/libnative-image-agent-class $CMDLINE $OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-pgo-instrumented.exe
  echo_and_exec $OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-pgo-instrumented.exe -Djava.home=$LEYDEN_HOME -XX:ProfilesDumpFile=$OUTPUT/Graal-EE/default.iprof $ARGS
  echo_and_exec $GRAALEE_HOME/bin/native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem --pgo=$OUTPUT/Graal-EE/default.iprof -cp $OUTPUT/Graal-EE/libnative-image-agent-class $CMDLINE $OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-pgo.exe
  echo_and_exec $GRAALEE_HOME/bin/native-image -g -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem -H:+PreserveFramePointer --pgo=$OUTPUT/Graal-EE/default.iprof -cp $OUTPUT/Graal-EE/libnative-image-agent-class $CMDLINE $OUTPUT_PROFILING/Graal-EE/JavacBenchApp-Graal-EE-pgo.exe

  echo_and_exec $GRAALEE_HOME/bin/native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem --gc=G1 --pgo-instrument -cp $OUTPUT/Graal-EE/libnative-image-agent-class $CMDLINE $OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-G1-pgo-instrumented.exe
  echo_and_exec $OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-G1-pgo-instrumented.exe -Djava.home=$LEYDEN_HOME -XX:ProfilesDumpFile=$OUTPUT/Graal-EE/g1.iprof $ARGS
  echo_and_exec $GRAALEE_HOME/bin/native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem --gc=G1 --pgo=$OUTPUT/Graal-EE/g1.iprof -cp $OUTPUT/Graal-EE/libnative-image-agent-class $CMDLINE $OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-G1-pgo.exe
  echo_and_exec $GRAALEE_HOME/bin/native-image -g -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem -H:+PreserveFramePointer --gc=G1 --pgo=$OUTPUT/Graal-EE/g1.iprof -cp $OUTPUT/Graal-EE/libnative-image-agent-class $CMDLINE $OUTPUT_PROFILING/Graal-EE/JavacBenchApp-Graal-EE-G1-pgo.exe

fi # if [[ -v BUILD ]]

modes=(
  "CDS-default"
  "CDS-static"
  "CDS-dynamic"
  "Leyden"
  "Leyden-PreloadOnly"
  "AOT"
  "AOT-PreloadOnly"
  "Graal-CE"
  "Graal-EE"
  "Graal-EE-G1"
  "Graal-EE-PGO"
  "Graal-EE-G1-PGO"
)

params=(
  "$LEYDEN_HOME/bin/java $CMDLINE"
  "$LEYDEN_HOME/bin/java -Xshare:on -XX:SharedArchiveFile=$OUTPUT/Static-CDS/JavacBench.static.jsa $CMDLINE"
  "$LEYDEN_HOME/bin/java -Xshare:on -XX:SharedArchiveFile=$OUTPUT/Dynamic-CDS/JavacBench.dynamic.jsa $CMDLINE"
  "$LEYDEN_HOME/bin/java -XX:CacheDataStore=$OUTPUT/Leyden/JavacBench.cds $CMDLINE"
  "$LEYDEN_HOME/bin/java -XX:CacheDataStore=$OUTPUT/Leyden/JavacBench.cds -XX:+UnlockExperimentalVMOptions -XX:+PreloadOnly $CMDLINE"
  "$LEYDEN_HOME/bin/java -XX:AOTMode=on -XX:AOTCache=$OUTPUT/AOT/JavacBench.aot $CMDLINE"
  "$LEYDEN_HOME/bin/java -XX:AOTMode=on -XX:AOTCache=$OUTPUT/AOT/JavacBench.aot -XX:+UnlockExperimentalVMOptions -XX:+PreloadOnly $CMDLINE"
  "$OUTPUT/Graal-CE/JavacBenchApp-Graal-CE.exe -Djava.home=$LEYDEN_HOME"
  "$OUTPUT/Graal-EE/JavacBenchApp-Graal-EE.exe -Djava.home=$LEYDEN_HOME"
  "$OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-G1.exe -Djava.home=$LEYDEN_HOME"
  "$OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-pgo.exe -Djava.home=$LEYDEN_HOME"
  "$OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-G1-pgo.exe -Djava.home=$LEYDEN_HOME"
)

params_profiling=(
  "$LEYDEN_HOME/bin/java $CMDLINE"
  "$LEYDEN_HOME/bin/java -Xshare:on -XX:SharedArchiveFile=$OUTPUT/Static-CDS/JavacBench.static.jsa $CMDLINE"
  "$LEYDEN_HOME/bin/java -Xshare:on -XX:SharedArchiveFile=$OUTPUT/Dynamic-CDS/JavacBench.dynamic.jsa $CMDLINE"
  "$LEYDEN_HOME/bin/java -XX:CacheDataStore=$OUTPUT_PROFILING/Leyden/JavacBench.cds $CMDLINE"
  "$LEYDEN_HOME/bin/java -XX:CacheDataStore=$OUTPUT_PROFILING/Leyden/JavacBench.cds -XX:+UnlockExperimentalVMOptions -XX:+PreloadOnly $CMDLINE"
  "$LEYDEN_HOME/bin/java -XX:AOTMode=on -XX:AOTCache=$OUTPUT_PROFILING/AOT/JavacBench.aot $CMDLINE"
  "$LEYDEN_HOME/bin/java -XX:AOTMode=on -XX:AOTCache=$OUTPUT_PROFILING/AOT/JavacBench.aot -XX:+UnlockExperimentalVMOptions -XX:+PreloadOnly $CMDLINE"
  "$OUTPUT_PROFILING/Graal-CE/JavacBenchApp-Graal-CE.exe -Djava.home=$LEYDEN_HOME"
  "$OUTPUT_PROFILING/Graal-EE/JavacBenchApp-Graal-EE.exe -Djava.home=$LEYDEN_HOME"
  "$OUTPUT_PROFILING/Graal-EE/JavacBenchApp-Graal-EE-G1.exe -Djava.home=$LEYDEN_HOME"
  "$OUTPUT_PROFILING/Graal-EE/JavacBenchApp-Graal-EE-pgo.exe -Djava.home=$LEYDEN_HOME"
  "$OUTPUT_PROFILING/Graal-EE/JavacBenchApp-Graal-EE-G1-pgo.exe -Djava.home=$LEYDEN_HOME"
)

DATADIR=$OUTPUT/data
echo_and_exec mkdir -p $DATADIR
TIMESTAMP=`date +%G-%m-%d-%H-%M`

if [[ -v TIME ]]; then
  for i in ${!modes[@]}; do
    echo_and_exec hyperfine -w 5 -r 30 -L iterations 1,100,10000 -u millisecond --style full --export-csv $DATADIR/${modes[$i]}-$TIMESTAMP.csv -n ${modes[$i]} "${params[$i]} {iterations}"
  done
fi

if [[ -v MEMORY ]]; then
  for i in ${!modes[@]}; do
    for iterations in "1" "100" "10000"; do
      for j in {1..10}; do
        echo_and_exec /usr/bin/time -o $DATADIR/${modes[$i]}-$iterations-$TIMESTAMP.rss -a -f %M ${params[$i]} $iterations
      done
    done
  done
fi

if [[ -v FLAMEGRAPH ]]; then
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
    "100"
    "10000"
  )
  for i in ${!modes[@]}; do
    for j in ${!iters[@]}; do
      iterations=${iters[$j]}
      if [[ ${modes[$i]} =~ "Graal" ]]; then
        echo_and_exec perf record -F ${perf[$j]} -g --call-graph fp -o $DATADIR/${modes[$i]}-$iterations-$TIMESTAMP.data ${params_profiling[$i]} $iterations
      else
        echo_and_exec perf record -F ${perf[$j]} -g --call-graph fp -o $DATADIR/${modes[$i]}-$iterations-$TIMESTAMP.data ${params_profiling[$i]/"java"/"java -XX:+PreserveFramePointer -XX:+UnlockDiagnosticVMOptions -XX:+DumpPerfMapAtExit"} $iterations
      fi
      echo_and_exec eval "perf script -i $DATADIR/${modes[$i]}-$iterations-$TIMESTAMP.data | stackcollapse-perf.pl --tid | flamegraph.pl --title=\"JavacBenchApp $iterations (${modes[$i]})\" --colors=java --inverted - > $DATADIR/${modes[$i]}-$iterations-$TIMESTAMP.svg"
      echo_and_exec rm $DATADIR/${modes[$i]}-$iterations-$TIMESTAMP.data
      if [[ ! ${modes[$i]} =~ "Graal" ]]; then
        echo_and_exec eval ${params_profiling[$i]/"java"/"java -agentpath:$ASYNCPROFILER_PATH/libasyncProfiler.so=start,event=cpu,interval=${async[$j]},flamegraph,threads,inverted,cstack=vm,title='JavacBenchApp $iterations (${modes[$i]})',file=$DATADIR/${modes[$i]}-$iterations-$TIMESTAMP.html"} $iterations
      fi
    done
  done
fi
