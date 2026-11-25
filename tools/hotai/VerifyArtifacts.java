import java.nio.file.*;
import java.util.*;
import java.util.jar.*;
import org.objectweb.asm.*;
import org.objectweb.asm.tree.*;
import org.badiff.MemoryDiffs;
import org.badiff.imp.MemoryDiff;
import org.badiff.io.DefaultSerialization;

/** Read-only check: a retained diff must reproduce the exact authoring class. */
public class VerifyArtifacts {
    public static void main(String[] args) throws Exception {
        byte[] expected = Files.readAllBytes(Path.of(args[1]));
        String target = new ClassReader(expected).getClassName();
        byte[] raw;
        try (JarFile jar = new JarFile(args[0])) {
            raw = jar.getInputStream(jar.getJarEntry(target + ".class")).readAllBytes();
        }
        // Match Hotai's ASM serialization, not raw JAR constant-pool ordering.
        ClassNode node = new ClassNode();
        new ClassReader(raw).accept(node, 0);
        ClassWriter writer = new ClassWriter(0);
        node.accept(writer);
        MemoryDiff diff = new MemoryDiff();
        try (var stream = Files.newInputStream(Path.of(args[2]))) {
            diff.deserialize(DefaultSerialization.newInstance(), stream);
        }
        if (!Arrays.equals(MemoryDiffs.apply(writer.toByteArray(), diff), expected)) {
            throw new AssertionError("Diff does not reproduce archived class: " + target);
        }
        System.out.println("PASS: archived class / diff byte-for-byte equivalence: " + target);
    }
}
