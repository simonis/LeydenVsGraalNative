#!/bin/bash

echo_and_exec() {
  if [[ -v DEBUG ]]; then
    echo "  ${@/eval/}"
  fi
  "$@"
}

OUTPUT="./build-10000_warmup_Serial_Xms256m_Xmx1g_2CPU"

CMDLINE="-cp $OUTPUT/JavacBenchApp.jar JavacBenchApp"
ARGS="10000"

if [[ -v BUILD ]]; then
  echo "Building .."

  echo_and_exec mkdir -p $OUTPUT
  echo_and_exec $LEYDEN_HOME/bin/javac --release 21 -d $OUTPUT/JavacBenchApp/ $LEYDEN_SRC/test/hotspot/jtreg/runtime/cds/appcds/applications/JavacBenchApp.java
  echo_and_exec $LEYDEN_HOME/bin/jar cf $OUTPUT/JavacBenchApp.jar -C $OUTPUT/JavacBenchApp .

  echo "Static-CDS"
  echo_and_exec mkdir -p $OUTPUT/Static-CDS
  echo_and_exec $LEYDEN_HOME/bin/java -XX:+UseSerialGC -Xms256m -Xmx1g -Xshare:off -XX:DumpLoadedClassList=$OUTPUT/Static-CDS/JavacBench.classlist $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java -XX:+UseSerialGC -Xms256m -Xmx1g -Xshare:dump -XX:SharedArchiveFile=$OUTPUT/Static-CDS/JavacBench.static.jsa -XX:SharedClassListFile=$OUTPUT/Static-CDS/JavacBench.classlist $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java -XX:+UseSerialGC -Xms256m -Xmx1g -Xshare:on -XX:SharedArchiveFile=$OUTPUT/Static-CDS/JavacBench.static.jsa $CMDLINE $ARGS

  echo "Dynamic-CDS"
  echo_and_exec mkdir -p $OUTPUT/Dynamic-CDS
  echo_and_exec $LEYDEN_HOME/bin/java -XX:+UseSerialGC -Xms256m -Xmx1g -XX:ArchiveClassesAtExit=$OUTPUT/Dynamic-CDS/JavacBench.dynamic.jsa $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java -XX:+UseSerialGC -Xms256m -Xmx1g -Xshare:on -XX:SharedArchiveFile=$OUTPUT/Dynamic-CDS/JavacBench.dynamic.jsa $CMDLINE $ARGS

  echo "Leyden"
  echo_and_exec mkdir -p $OUTPUT/Leyden
  echo_and_exec rm -f $OUTPUT/Leyden/JavacBench.cds
  echo_and_exec $LEYDEN_HOME/bin/java -XX:+UseSerialGC -Xms256m -Xmx1g -XX:+AOTClassLinking -XX:+ArchiveDynamicProxies -XX:CacheDataStore=$OUTPUT/Leyden/JavacBench.cds $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java -XX:+UseSerialGC -Xms256m -Xmx1g -XX:CacheDataStore=$OUTPUT/Leyden/JavacBench.cds $CMDLINE $ARGS

  echo "AOT"
  echo_and_exec mkdir -p $OUTPUT/AOT
  echo_and_exec $LEYDEN_HOME/bin/java -XX:+UseSerialGC -Xms256m -Xmx1g -XX:AOTMode=record -XX:AOTConfiguration=$OUTPUT/AOT/JavacBench.aotconfig $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java -XX:+UseSerialGC -Xms256m -Xmx1g -XX:AOTMode=create -XX:AOTConfiguration=$OUTPUT/AOT/JavacBench.aotconfig -XX:AOTCache=$OUTPUT/AOT/JavacBench.aot $CMDLINE $ARGS
  echo_and_exec $LEYDEN_HOME/bin/java -XX:+UseSerialGC -Xms256m -Xmx1g -XX:AOTMode=on -XX:AOTCache=$OUTPUT/AOT/JavacBench.aot $CMDLINE $ARGS

  echo "Graal-CE"
  echo_and_exec mkdir -p $OUTPUT/Graal-CE
  echo_and_exec $GRAALCE_HOME/bin/java -agentlib:native-image-agent=config-output-dir=$OUTPUT/Graal-CE/libnative-image-agent-class,experimental-class-define-support $CMDLINE $ARGS
  echo_and_exec mkdir -p $OUTPUT/Graal-CE/libnative-image-agent-class/META-INF/native-image
  echo_and_exec cp -rf $OUTPUT/Graal-CE/libnative-image-agent-class/agent-extracted-predefined-classes $OUTPUT/Graal-CE/libnative-image-agent-class/*.json $OUTPUT/Graal-CE/libnative-image-agent-class/META-INF/native-image/
  echo_and_exec $GRAALCE_HOME/bin/native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem -cp $OUTPUT/Graal-CE/libnative-image-agent-class $CMDLINE $OUTPUT/Graal-CE/JavacBenchApp-Graal-CE.exe

  echo "Graal-EE"
  echo_and_exec mkdir -p $OUTPUT/Graal-EE
  echo_and_exec $GRAALEE_HOME/bin/java -agentlib:native-image-agent=config-output-dir=$OUTPUT/Graal-EE/libnative-image-agent-class,experimental-class-define-support $CMDLINE $ARGS
  echo_and_exec mkdir -p $OUTPUT/Graal-EE/libnative-image-agent-class/META-INF/native-image
  echo_and_exec cp -rf $OUTPUT/Graal-EE/libnative-image-agent-class/agent-extracted-predefined-classes $OUTPUT/Graal-EE/libnative-image-agent-class/*.json $OUTPUT/Graal-EE/libnative-image-agent-class/META-INF/native-image/
  echo_and_exec $GRAALEE_HOME/bin/native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem -cp $OUTPUT/Graal-EE/libnative-image-agent-class $CMDLINE $OUTPUT/Graal-EE/JavacBenchApp-Graal-EE.exe

  echo_and_exec $GRAALEE_HOME/bin/native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem --gc=G1 -cp $OUTPUT/Graal-EE/libnative-image-agent-class $CMDLINE $OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-G1.exe

  echo_and_exec $GRAALEE_HOME/bin/native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem --pgo-instrument -cp $OUTPUT/Graal-EE/libnative-image-agent-class $CMDLINE $OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-pgo-instrumented.exe
  echo_and_exec $OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-pgo-instrumented.exe -Djava.home=$LEYDEN_HOME -XX:ProfilesDumpFile=$OUTPUT/Graal-EE/default.iprof $ARGS
  echo_and_exec $GRAALEE_HOME/bin/native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem --pgo=$OUTPUT/Graal-EE/default.iprof -cp $OUTPUT/Graal-EE/libnative-image-agent-class $CMDLINE $OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-pgo.exe

  echo_and_exec $GRAALEE_HOME/bin/native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem --gc=G1 --pgo-instrument -cp $OUTPUT/Graal-EE/libnative-image-agent-class $CMDLINE $OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-G1-pgo-instrumented.exe
  echo_and_exec $OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-G1-pgo-instrumented.exe -Djava.home=$LEYDEN_HOME -XX:ProfilesDumpFile=$OUTPUT/Graal-EE/g1.iprof $ARGS
  echo_and_exec $GRAALEE_HOME/bin/native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem --gc=G1 --pgo=$OUTPUT/Graal-EE/g1.iprof -cp $OUTPUT/Graal-EE/libnative-image-agent-class $CMDLINE $OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-G1-pgo.exe

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
  "$LEYDEN_HOME/bin/java -XX:+UseSerialGC -Xms256m -Xmx1g $CMDLINE"
  "$LEYDEN_HOME/bin/java -XX:+UseSerialGC -Xms256m -Xmx1g -Xshare:on -XX:SharedArchiveFile=$OUTPUT/Static-CDS/JavacBench.static.jsa $CMDLINE"
  "$LEYDEN_HOME/bin/java -XX:+UseSerialGC -Xms256m -Xmx1g -Xshare:on -XX:SharedArchiveFile=$OUTPUT/Dynamic-CDS/JavacBench.dynamic.jsa $CMDLINE"
  "$LEYDEN_HOME/bin/java -XX:+UseSerialGC -Xms256m -Xmx1g -XX:CacheDataStore=$OUTPUT/Leyden/JavacBench.cds $CMDLINE"
  "$LEYDEN_HOME/bin/java -XX:+UseSerialGC -Xms256m -Xmx1g -XX:CacheDataStore=$OUTPUT/Leyden/JavacBench.cds -XX:+UnlockExperimentalVMOptions -XX:+PreloadOnly $CMDLINE"
  "$LEYDEN_HOME/bin/java -XX:+UseSerialGC -Xms256m -Xmx1g -XX:AOTMode=on -XX:AOTCache=$OUTPUT/AOT/JavacBench.aot $CMDLINE"
  "$LEYDEN_HOME/bin/java -XX:+UseSerialGC -Xms256m -Xmx1g -XX:AOTMode=on -XX:AOTCache=$OUTPUT/AOT/JavacBench.aot -XX:+UnlockExperimentalVMOptions -XX:+PreloadOnly $CMDLINE"
  "$OUTPUT/Graal-CE/JavacBenchApp-Graal-CE.exe -Xms256m -Xmx1g -Djava.home=$LEYDEN_HOME"
  "$OUTPUT/Graal-EE/JavacBenchApp-Graal-EE.exe -Xms256m -Xmx1g -Djava.home=$LEYDEN_HOME"
  "$OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-G1.exe -Xms256m -Xmx1g -Djava.home=$LEYDEN_HOME"
  "$OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-pgo.exe -Xms256m -Xmx1g -Djava.home=$LEYDEN_HOME"
  "$OUTPUT/Graal-EE/JavacBenchApp-Graal-EE-G1-pgo.exe -Xms256m -Xmx1g -Djava.home=$LEYDEN_HOME"
)

DATADIR=$OUTPUT/data
echo_and_exec mkdir -p $DATADIR
TIMESTAMP=`date +%G-%m-%d-%H-%M`

if [[ -v TIME ]]; then
  for i in ${!modes[@]}; do
    echo_and_exec taskset -c 8,9 hyperfine -w 5 -r 30 -L iterations 1,100,10000 -u millisecond --style full --export-csv $DATADIR/${modes[$i]}-$TIMESTAMP.csv -n ${modes[$i]} "${params[$i]} {iterations}"
  done
fi

if [[ -v MEMORY ]]; then
  for i in ${!modes[@]}; do
    for iterations in "1" "100" "10000"; do
      for j in {1..10}; do
        echo_and_exec taskset -c 8,9 /usr/bin/time -o $DATADIR/${modes[$i]}-$iterations-$TIMESTAMP.rss -a -f %M ${params[$i]} $iterations
      done
    done
  done
fi
