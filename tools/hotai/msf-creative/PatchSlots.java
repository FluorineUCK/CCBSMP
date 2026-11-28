import java.nio.file.*;
import java.security.*;
import java.util.*;
import org.objectweb.asm.*;
import org.objectweb.asm.tree.*;
import org.objectweb.asm.tree.analysis.*;
import org.badiff.MemoryDiffs;
import org.badiff.imp.MemoryDiff;
import org.badiff.io.DefaultSerialization;

public class PatchSlots implements Opcodes {
    static final String JAR_SHA="1a84878443b85d9e9623fc59c7fa7fe31562030d669a2adf08780325aeb917b0";
    public static void main(String[] args)throws Exception {
        Path jar=Path.of(args[0]),out=Path.of(args[1]);
        String hash=HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(jar)));
        if(!hash.equals(JAR_SHA))throw new IllegalArgumentException("Unsupported JAR hash: "+hash);
        ClassNode c=TestSlots.read(TestSlots.original(args[0]));
        ClassWriter baseline=new ClassWriter(0);c.accept(baseline);byte[] original=baseline.toByteArray();
        MethodNode m=TestSlots.method(c);
        if(!m.desc.equals("(Lnet/minecraft/core/NonNullList;Lcom/llamalad7/mixinextras/injector/wrapoperation/Operation;)I"))throw new AssertionError("Unexpected descriptor");
        int removed=0;
        for(AbstractInsnNode n:m.instructions.toArray()) {
            if(n.getOpcode()==ICONST_2 && n.getNext().getOpcode()==ISUB && n.getNext().getNext().getOpcode()==IRETURN) {
                m.instructions.remove(n.getNext());m.instructions.remove(n);removed++;
            }
        }
        if(removed!=1)throw new AssertionError("Expected one trailing subtraction, got "+removed);
        // Leave superclass, all other methods, Mixin annotations and Operation invocation intact.
        ClassWriter w=new ClassWriter(0);c.accept(w);byte[] patched=w.toByteArray();
        for(MethodNode method:TestSlots.read(patched).methods)new Analyzer<>(new BasicVerifier()).analyze(c.name,method);
        TestSlots.verify(patched);
        Path full=out.resolve("classes/"+TestSlots.TARGET+".class"),diffPath=out.resolve("hotai/"+TestSlots.TARGET+".badiff");
        Files.createDirectories(full.getParent());Files.createDirectories(diffPath.getParent());Files.write(full,patched);
        // Hotai's baseline is ClassNode -> ClassWriter(0), NOT raw JAR bytes.
        try(var stream=Files.newOutputStream(diffPath)){MemoryDiffs.diff(original,patched).serialize(DefaultSerialization.newInstance(),stream);}
        MemoryDiff diff=new MemoryDiff();try(var stream=Files.newInputStream(diffPath)){diff.deserialize(DefaultSerialization.newInstance(),stream);}
        if(!Arrays.equals(MemoryDiffs.apply(original,diff),patched))throw new AssertionError("badiff round trip mismatch");
        System.out.println("PASS: removed only ICONST_2/ISUB; ASM verified; serialized badiff reconstructs full class");
    }
}
