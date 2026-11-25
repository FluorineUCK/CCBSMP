import java.nio.file.*;
import java.security.*;
import java.util.*;
import java.util.jar.*;
import org.objectweb.asm.*;
import org.objectweb.asm.tree.*;
import org.objectweb.asm.tree.analysis.*;
import org.badiff.MemoryDiffs;
import org.badiff.imp.MemoryDiff;
import org.badiff.io.DefaultSerialization;

public class PatchRecovery implements Opcodes {
    static final String TARGET = "dev/leo/sableplayerragdoll/mob/MobRagdollSourceRecovery";
    static final String JAR_SHA = "52231de8cf20713040e948ec41c0813d8b1eab2e7ec327c1ff5da8bdc3ba33fd";
    static final String NBT = "net/minecraft/nbt/CompoundTag";
    static final String ENTITY = "net/minecraft/world/entity/LivingEntity";
    public static void main(String[] args) throws Exception {
        Path jar=Path.of(args[0]), out=Path.of(args[1]);
        String hash=HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(jar)));
        if(!hash.equals(JAR_SHA)) throw new IllegalArgumentException("Unsupported target JAR: "+hash);
        byte[] raw;
        try(JarFile j=new JarFile(jar.toFile())) { raw=j.getInputStream(j.getJarEntry(TARGET+".class")).readAllBytes(); }
        ClassNode c=new ClassNode(); new ClassReader(raw).accept(c,0);
        // Hotai serializes the incoming ClassNode with ClassWriter(0), not the raw JAR bytes.
        ClassWriter baseline=new ClassWriter(0); c.accept(baseline); byte[] original=baseline.toByteArray();
        int count=0;
        for(MethodNode m:c.methods) {
            if(!m.name.equals("active")) continue;
            boolean entity=m.desc.equals("(L"+ENTITY+";)Z");
            if(!entity && !m.desc.equals("(L"+NBT+";J)Z")) throw new AssertionError("Unexpected overload");
            LabelNode present=new LabelNode(); InsnList guard=new InsnList();
            guard.add(new VarInsnNode(ALOAD,0));
            if(entity) guard.add(new MethodInsnNode(INVOKEVIRTUAL,ENTITY,"getPersistentData","()L"+NBT+";",false));
            guard.add(new LdcInsnNode("sable_player_ragdoll_mob_recovery"));
            guard.add(new IntInsnNode(BIPUSH,10));
            guard.add(new MethodInsnNode(INVOKEVIRTUAL,NBT,"contains","(Ljava/lang/String;I)Z",false));
            guard.add(new JumpInsnNode(IFNE,present));
            guard.add(new InsnNode(ICONST_0)); guard.add(new InsnNode(IRETURN));
            guard.add(present); guard.add(new FrameNode(F_SAME,0,null,0,null));
            m.instructions.insert(guard); count++;
        }
        if(count!=2) throw new AssertionError("Expected two active overloads");
        ClassWriter w=new ClassWriter(ClassWriter.COMPUTE_MAXS); c.accept(w); byte[] patched=w.toByteArray();
        ClassNode check=new ClassNode(); new ClassReader(patched).accept(check,0);
        for(MethodNode m:check.methods) new Analyzer<>(new BasicVerifier()).analyze(check.name,m);
        Files.createDirectories(out); Files.write(out.resolve("patched.class"),patched);
        Path diffPath=out.resolve("hotai/"+TARGET+".badiff"); Files.createDirectories(diffPath.getParent());
        try(var stream=Files.newOutputStream(diffPath)) { MemoryDiffs.diff(original,patched).serialize(DefaultSerialization.newInstance(),stream); }
        MemoryDiff diff=new MemoryDiff();
        try(var stream=Files.newInputStream(diffPath)) { diff.deserialize(DefaultSerialization.newInstance(),stream); }
        if(!Arrays.equals(MemoryDiffs.apply(original,diff),patched)) throw new AssertionError("badiff round trip");
        System.out.println("PASS: two guards, ASM verification, Hotai-normalized badiff round trip: "+diffPath);
    }
}
