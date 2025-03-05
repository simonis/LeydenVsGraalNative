## Leyden vs. Graal Native Image

This is a preliminary (as of March 2025) comparison of the CPU and memory consumption of the simple [`JavacBenchApp`](https://github.com/openjdk/leyden/blob/8204ccbc0161306295d6c433e0048f7bba8c9041/test/hotspot/jtreg/runtime/cds/appcds/applications/JavacBench.java) application from Leyden's JTreg tests. The program uses the `javax.tools` interface to programmatically compile a variable number of Java classes created from a string template and tries to exercise a fair amount of `javac` features. The number of compiled classes can be given as a command line parameter. At the end of its execution, the program dynamically loads one of the compiled classes and calls a method from it.

Read on for the details about what the following graph is actually displaying and how it was created :)

![](graphs/2025-03-04-09-04/JavacBenchApp1.svg){width=100%}

### Test modifications

The original test uses [`Lookup.defineClass(byte [])`](https://docs.oracle.com/en/java/javase/23/docs/api/java.base/java/lang/invoke/MethodHandles.Lookup.html#defineClass(byte[])) to dynamically load a compiled class in the current class loader. This isn't currently supported by Native Image, but Native Image has [experimental support for dynamic class loading](https://www.graalvm.org/jdk23/reference-manual/native-image/metadata/ExperimentalAgentOptions/#support-for-predefined-classes) with the help of their [Tracing Agent](https://www.graalvm.org/jdk23/reference-manual/native-image/metadata/AutomaticMetadataCollection/). However, this only works for classes not loaded by one of the Java VM’s built-in class loaders, so I slightly changed the test to dynamically load the class into an anonymous custom class loader:

```patch
@@ -196,8 +196,15 @@ void setup(int count) {

     @SuppressWarnings("unchecked")
     static void validate(byte[] sanityClassFile) throws Throwable {
-        MethodHandles.Lookup lookup = MethodHandles.lookup();
-        Class<?> cls = lookup.defineClass(sanityClassFile);
+        Class<?> cls = new ClassLoader() {
+            public Class findClass(String name) {
+                return defineClass(name, sanityClassFile, 0, sanityClassFile.length);
+            }
+        }.findClass("Sanity");
         Callable<String> obj = (Callable<String>)cls.getDeclaredConstructor().newInstance();
         String s = obj.call();
         if (!s.equals("this is a test")) {
```
Also, because the Native Image tool uses an old version of `org.objectweb.asm`, it can't parse Java 25 class files. I therefore changed the test to produce Java 21 class files instead:

```patch
@@ -99,7 +99,7 @@ public Map<String, byte[]> compile() {
         Collection<SourceFile> sourceFiles = sources;

         try (FileManager fileManager = new FileManager(compiler.getStandardFileManager(ds, null, null))) {
-            JavaCompiler.CompilationTask task = compiler.getTask(null, fileManager, null, null, null, sourceFiles);
+            JavaCompiler.CompilationTask task = compiler.getTask(null, fileManager, null, List.of("--release", "21"), null, sourceFiles);
             if (task.call()) {
                 return fileManager.getCompiledClasses();
             } else {
```

These changes can be found in my private [JavacBenchApp-for-GraalNativeImage](https://github.com/simonis/leyden/blob/JavacBenchApp-for-GraalNativeImage/test/hotspot/jtreg/runtime/cds/appcds/applications/JavacBenchApp.java) branch of Leyden/premain.

### Test environment

For the Leyden tests I used a private build of the Leyden [premain](https://github.com/openjdk/leyden/tree/premain) branch at commit [432069bf72a](https://github.com/openjdk/leyden/commit/432069bf72af6c26a922a0fe9a6b20b06c7c0599) with the test changes described before.

For the Graal Native Image tests I used a private build of the [Graal master branch](https://github.com/oracle/graal) at commit [3cae6b41a41](https://github.com/oracle/graal/commit/3cae6b41a41119d0694f53ec84d703db56d96325) (built with [OpenJDK master](https://github.com/openjdk/jdk) at commit [bd112c4fab8](https://github.com/openjdk/jdk/commit/bd112c4fab8c6b6a8181d4629009b6cb408727a1)) for Graal CE and the early access version of [Oracle GraalVM for JDK 25 - 25.0.0-ea11](https://github.com/graalvm/oracle-graalvm-ea-builds/releases/tag/jdk-25.0.0-ea.11) for Graal EE.

Notice that Leyden as well as Graal Native Image are under heavy development, so the current comparison can only be a snapshot!

For measuring the runtime (i.e. wall clock, user and system time), I used [`hyperfine`](https://github.com/sharkdp/hyperfine) and for measuring RSS I used [`/usr/bin/time -f %M`](https://man7.org/linux/man-pages/man1/time.1.html).

All the benchmarks were taken on an empty [c5.metal](https://instances.vantage.sh/aws/ec2/c5.metal) instance with an Intel Xeon Platinum 8275L with 48 cores / 96 hyperthreads running at 3.00GHz and 192gb of main memory on Amazon Linux 2023.6.20250115.

### Test modes

In JTreg, `JavacBenchApp` is executed by the [`JavacBench`](https://github.com/openjdk/leyden/blob/8204ccbc0161306295d6c433e0048f7bba8c9041/test/hotspot/jtreg/runtime/cds/appcds/applications/JavacBench.java) in four modes, STATIC, DYNAMIC, LEYDEN and AOT. In the following sections I'll summarize what these modes mean. The last line in each sections describes how the benchmarks was actually run.

**STATIC**
```
$ java -Xshare:off -XX:DumpLoadedClassList=JavacBench.classlist -cp JavacBenchApp.jar JavacBenchApp 90
$ java -Xshare:dump -XX:SharedArchiveFile=JavacBench.static.jsa -XX:SharedClassListFile=JavacBench.classlist -cp JavacBenchApp.jar JavacBenchApp 90
$ java -Xshare:on -XX:SharedArchiveFile=JavacBench.static.jsa -cp JavacBenchApp.jar JavacBenchApp <iterations>
```

**DYNAMIC**
```
$ java -XX:ArchiveClassesAtExit=JavacBench.dynamic.jsa -cp JavacBenchApp.jar JavacBenchApp 90
$ java -Xshare:on -XX:SharedArchiveFile=JavacBench.dynamic.jsa -cp JavacBenchApp.jar JavacBenchApp <iterations>
```

**LEYDEN**
```
$ java -XX:+AOTClassLinking -XX:+ArchiveDynamicProxies -XX:CacheDataStore=JavacBench.cds -cp JavacBenchApp.jar JavacBenchApp 90
$ java -XX:CacheDataStore=JavacBench.cds -cp JavacBenchApp.jar JavacBenchApp 90
```

**AOT**
```
$ java -XX:AOTMode=record -XX:AOTConfiguration=JavacBench.aotconfig -cp JavacBenchApp.jar JavacBenchApp 90
$ java -XX:AOTMode=create -XX:AOTConfiguration=JavacBench.aotconfig -XX:AOTCache=JavacBench.aot -cp JavacBenchApp.jar JavacBenchApp 90
$ java -XX:AOTMode=on -XX:AOTCache=JavacBench.aot -cp JavacBenchApp.jar JavacBenchApp <iterations>
```

The LEYDEN/AOT mode was executed two times, once with the default settings and once with [`-XX:+PreloadOnly`](https://github.com/openjdk/leyden/pull/44).

For Graal Native Image CE and EE I prepared the native executables as follows:

**GRAAL CE/EE**
```
$ java -agentlib:native-image-agent=config-output-dir=libnative-image-agent-class,experimental-class-define-support -cp JavacBenchApp.jar JavacBenchApp 90
$ mkdir -p libnative-image-agent-class/META-INF/native-image
$ cp -rf libnative-image-agent-class/agent-extracted-predefined-classes libnative-image-agent-class/*.json libnative-image-agent-class/META-INF/native-image/
$ native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem -cp libnative-image-agent-class -cp JavacBenchApp.jar JavacBenchApp JavacBenchApp.exe
```

For Graal EE I also created executable with G1 and [Profile Guided Optimization](https://www.graalvm.org/latest/reference-manual/native-image/guides/optimize-native-executable-with-pgo/) (PGO) as follows:

**GRALL EE G1**
```
...<as before>..
$ native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem --gc=G1 -cp libnative-image-agent-class -cp JavacBenchApp.jar JavacBenchApp JavacBenchApp.exe
```

**GRALL EE PGO**
```
...<as before>..
$ native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem --pgo-instrument -cp libnative-image-agent-class -cp JavacBenchApp.jar JavacBenchApp JavacBenchApp-instrumented.exe
$ JavacBenchApp-instrumented.exe -Djava.home=$JAVA_HOME -XX:ProfilesDumpFile=default.iprof 90
$ native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem --pgo=default.iprof -cp libnative-image-agent-class -cp JavacBenchApp.jar JavacBenchApp JavacBenchApp.exe
```

**GRALL EE G1 PGO**
```
...<as before>..
$ native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem  --gc=G1 --pgo-instrument -cp libnative-image-agent-class -cp JavacBenchApp.jar JavacBenchApp JavacBenchApp-instrumented.exe
$ JavacBenchApp-instrumented.exe -Djava.home=$JAVA_HOME -XX:ProfilesDumpFile=g1.iprof 90
$ native-image -H:+UnlockExperimentalVMOptions -H:+AllowJRTFileSystem  --gc=G1 --pgo=g1.iprof -cp libnative-image-agent-class -cp JavacBenchApp.jar JavacBenchApp JavacBenchApp.exe
```

When running the created native executables we have to manually set the `java.home` property on the command line with `-Djava.home=<JAVA_HOME>` to avoid null pointer exceptions because a [native image doesn't have `java.home` set by default](https://www.graalvm.org/latest/reference-manual/native-image/guides/troubleshoot-run-time-errors/#2-set-javahome-explicitly).

For the run-time benchmarks I did run each mode 30 times and for measuring RSS, each mode was executed 10 times.

The exact commands can be found in the [scripts/run.sh](./scripts/run.sh) script which was used to build and run the test. It can be run as follows from the top-level directory of this repository:
```bash
$ BUILD=true TIME=TRUE MEMORY=true ./scripts/run.sh
```
The script expects the the environment variables `LEYDEN_HOME`, `LEYDEN_SRC`, `GRAALCE_HOME` and `GRAALEE_HOME` are set accordingly and `hperfine` is in the path. It will create the directory `./build/` directory for all the required build artefacts and place all the raw benchmarks data under `./build/data/`. The CPU time benchmarks end in `.csv`, the RSS measurement end in `.rss`. All the data files from a single invocation of `run.sh` contain the same time stamp as part of their file name. Setting the environment variable `DEBUG` to true will echo each command on the console before executing it.

### Results

Following are the results for running `JavacBench 1`:

![](graphs/2025-03-04-09-04/JavacBenchApp1.svg){width=100%}

The left graph shows the wall clock time for each configuration. "CDS (default)" is Leyden with the default CDS archive created during the build and should be equivalent to the corresponding version of OpenJDK. Its wall clock time is set to 100%. All the other percentage labels denote the relative runtime compared to the "CDS (default)" mode.

The right graph displays the sum of user plus system time for the configurations in the left graph. Notice that each percentage label on the right graph shows the proportion of user and system time compared to the wall clock time of the same configuration. E.g. `JavacBench 1` runs 526ms in the "CDS (default)" mode (upper, blue bar in the left graph) but it consumes 1411ms of user and system time (upper blue bar in the right graph) which is 268% of wall clock time. This means that `JavacBench 1` used ~2.6 CPUs during its run time. As mentioned in the [Test environment](#test-environment) section, these tests where running on a machine with plenty of free cores, so the proportion of wall clock time to user time shows the "parallelism" of the application (or to be more precise, the parallelism of the JVM because the application itself is single threaded). So the additional user time basically accounts for for concurrent JIT and GC activity.

The graph for running `JavacBench 100` looks as follows:

![](graphs/2025-03-04-09-04/JavacBenchApp100.svg){width=100%}

And finally the graph for compiling 10000 classes with `JavacBench 100`:

![](graphs/2025-03-04-09-04/JavacBenchApp10000.svg){width=100%}

#### Interpreting the results

### Appendix

#### Creating the graphs

Disclaimer: this workflow is quite specific to this exact use case and will hardly work out of the box for anything else !!!

For the CPU time graphs, the raw data files (e.g. [`./data/2025-03-04-09-04/AOT-2025-03-04-09-04.csv`](data/2025-03-04-09-04/AOT-2025-03-04-09-04.csv)) are first processed and converted into [vega-lite](https://vega.github.io/vega-lite/) specification with the help of [`./scripts/ProcessHyperfineResults.java`](scripts/ProcessHyperfineResults.java) as follows:

```bash
$ java ./scripts/ProcessHyperfineResults.java 10000 scripts/TemplateJavacBenchAppCPU.json /tmp/JavacBenchApp10000.json build/data/*03-04*.csv
```
The first argument (i.e. `10000` in this example) is the argument given to the `JavacBenchApp` (because each `.csv` file contains the data for one configuration but for runs with different parameters), the second argument is the vega-lie template file to use, the third argument denotes the output file (i.e. the created vega-lite specification) and the remaining arguments (usually a wildcard expression) are the raw input data files created by [`./scripts/run.sh`](scripts/run.sh)

The vega-lite specifications are then transformed into SVG graphs as follows. First we create a Docker container with the vega-lite toolchain as follows:
```bash
$ docker build -t vega-lite -f scripts/Dockerfile.vega .
```

Once the container has been created, we can use it as follows:
```bash
$ docker run --rm -i vega-lite --scale 2 < vega-lite-spec.json > graph.svg
```
