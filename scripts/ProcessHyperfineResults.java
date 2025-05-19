import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;

public class ProcessHyperfineResults {
    private static Map<String, String> modes;
    private static Map<String, Integer> order;

    static {
        modes = new LinkedHashMap<>();
        modes.put("JDK24-Default", "JDK24 (default CDS)");
        modes.put("JDK24-Static-CDS", "JDK24 (static CDS)");
        modes.put("JDK24-Dynamic-CDS", "JDK24 (dynamic CDS)");
        modes.put("JDK24-JEP483", "JDK24 (JEP 483)");
        modes.put("Leyden-Premain", "Leyden");
        modes.put("Leyden-Premain", "Leyden (PreloadOnly)");
        modes.put("Graal-CE", "Graal (CE)");
        modes.put("Graal-EE", "Graal (EE)");
        modes.put("Graal-EE-G1", "Graal (EE G1)");
        modes.put("Graal-EE-PGO", "Graal (EE PGO)");
        modes.put("Graal-EE-G1-PGO", "Graal (EE G1 PGO)");
        order = new HashMap<>(modes.size());
        int i = 0;
        for (String m : modes.keySet()) {
            order.put(m, i++);
        }
    }

    public static void main(String[] args) throws Exception {
        String iterations = args[0];
        String template = Files.readString(Path.of(args[1]));
        Path output = Path.of(args[2]);
        String[] data = new String[2 * modes.size()];
        Arrays.stream(args, 3, args.length).forEach(arg -> {
            try {
                Files.lines(Path.of(arg)).skip(1).filter(s -> {
                    String[] fields = s.split(",");
                    return fields[fields.length - 1].equals(iterations);
                }).forEach(line -> {
                    String[] fields = line.split(",");
                    data[2 * order.get(fields[0])] = String.format("{\"type\": \"%s\", \"wall\": \"%d\", \"user\": \"%d\", \"system\": \"%d\", \"file\": \"wall clock time\"}",
                            modes.get(fields[0]), (int) (Double.parseDouble(fields[1]) * 1000), (int) (Double.parseDouble(fields[4]) * 1000), (int) (Double.parseDouble(fields[5]) * 1000));
                    data[2 * order.get(fields[0]) + 1] = String.format("{\"type\": \"%s\", \"wall\": \"%d\", \"user\": \"%d\", \"system\": \"%d\", \"file\": \"user+sys time (%% rel. to wall time)\"}",
                            modes.get(fields[0]), (int) (Double.parseDouble(fields[1]) * 1000), (int) (Double.parseDouble(fields[4]) * 1000), (int) (Double.parseDouble(fields[5]) * 1000));
                });
            } catch (IOException e) {
                System.out.println(e);
            }
        });
        template = template.replace("__ITERATIONS__", iterations);
        template = template.replace("__CONFIGURATION__", System.getProperty("configuration", ""));
        template = template.replace("__DATA__", Arrays.stream(data).collect(Collectors.joining(",\n")));
        template = template.replace("__SORT__", modes.values().stream().map(s -> "\"" + s + "\"").collect(Collectors.joining(", ")));
        Files.writeString(output, template, StandardOpenOption.CREATE_NEW /* Don't overwrite any existing files */);
    }
}
