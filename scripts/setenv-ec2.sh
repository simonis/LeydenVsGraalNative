export JDK21_HOME=/priv/ec2-user/output/jdk21u-dev-opt/images/jdk
export JDK24_HOME=/priv/ec2-user/output/jdk24u-opt/images/jdk
export LEYDEN_HOME=/priv/ec2-user/output/leyden-opt/images/jdk
export LEYDEN_SRC=/priv/ec2-user/OpenJDK/Git/leyden
export LEYDEN_PETCLINIC=/priv/ec2-user/OpenJDK/Git/leyden/test/hotspot/jtreg/premain/spring-petclinic
export GRAALCE_HOME=/priv/ec2-user/Git/Graal/graal/sdk/latest_graalvm/graalvm-1fd394836d-java25-25.0.0-dev/
export GRAALEE_HOME=/share/software/Java/graalvm-jdk-25+22.1
export ASYNCPROFILER_PATH=/priv/ec2-user/Git/async-profiler/build/lib
export PATH=/priv/ec2-user/Git/FlameGraph:$PATH

DEBUG=true BUILD=true TIME=true MEMORY=true FLAMEGRAPH=true GC_ARG= HEAP_ARGS= TASKSET= ./scripts/run.sh
