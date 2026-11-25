import java.nio.file.*;
import java.util.*;
import java.util.jar.*;
import org.objectweb.asm.*;
import org.objectweb.asm.tree.*;
import org.objectweb.asm.tree.analysis.*;

public class PatchMoreCulling {
    static final String TARGET="ca/fxco/moreculling/mixin/models/cullshape/BlockStateBase_cullShapeMixin";
    static final String ARRAY="[Lnet/minecraft/world/phys/shapes/VoxelShape;";
    static boolean offending(AbstractInsnNode n) {
        return n instanceof MethodInsnNode m && m.getOpcode()==Opcodes.INVOKEVIRTUAL && m.owner.equals(ARRAY) && m.name.equals("clone") && m.desc.equals("()Ljava/lang/Object;");
    }
    static ClassNode read(byte[] b) {ClassNode n=new ClassNode(); new ClassReader(b).accept(n,0);return n;}
    static MethodNode target(ClassNode c) {return c.methods.stream().filter(m->m.name.equals("moreculling$initShapeCache") && m.desc.equals("()V")).findFirst().orElseThrow();}
    static void verify(byte[] b) throws Exception {
        ClassNode c=read(b);if(!c.name.equals(TARGET))throw new AssertionError("Wrong class");
        for(AbstractInsnNode n:target(c).instructions) if(offending(n))throw new AssertionError("Regression: array-owner clone invocation still reaches Mixin");
        for(MethodNode m:c.methods)if((m.access&(Opcodes.ACC_ABSTRACT|Opcodes.ACC_NATIVE))==0)new Analyzer<>(new BasicVerifier()).analyze(c.name,m);
        // Execute the exact replacement stack sequence on a typed array in an isolated generated class.
        ClassWriter w=new ClassWriter(ClassWriter.COMPUTE_MAXS);w.visit(Opcodes.V21,Opcodes.ACC_PUBLIC,"ArrayCopyProbe",null,"java/lang/Object",null);
        MethodVisitor mv=w.visitMethod(Opcodes.ACC_PUBLIC|Opcodes.ACC_STATIC,"copy","([Ljava/lang/Object;)[Ljava/lang/Object;",null,null);mv.visitCode();mv.visitVarInsn(Opcodes.ALOAD,0);mv.visitInsn(Opcodes.DUP);mv.visitInsn(Opcodes.ARRAYLENGTH);mv.visitMethodInsn(Opcodes.INVOKESTATIC,"java/util/Arrays","copyOf","([Ljava/lang/Object;I)[Ljava/lang/Object;",false);mv.visitInsn(Opcodes.ARETURN);mv.visitMaxs(0,0);mv.visitEnd();w.visitEnd();byte[] probe=w.toByteArray();
        class ProbeLoader extends ClassLoader {Class<?> define(){return defineClass(null,probe,0,probe.length);}}
        var copy=new ProbeLoader().define().getMethod("copy",Object[].class);
        for(String[] src:new String[][]{new String[0],new String[]{"a",null,"b"}}){Object[] dst=(Object[])copy.invoke(null,(Object)src);if(dst==src || dst.getClass()!=src.getClass() || !Arrays.equals(dst,src))throw new AssertionError("Copy semantics");if(dst.length>0){dst[0]="changed";if(!src[0].equals("a"))throw new AssertionError("Aliasing");}}
        System.out.println("PASS: offending call absent; ASM BasicVerifier; independent copy, contents, runtime array type, empty array");
    }
    public static void main(String[] a)throws Exception{
        if(a[0].equals("check")){verify(Files.readAllBytes(Path.of(a[1])));return;}
        byte[] original;try(JarFile j=new JarFile(a[1])){original=j.getInputStream(j.getJarEntry(TARGET+".class")).readAllBytes();}
        Path out=Path.of(a[2]);Files.createDirectories(out);Files.write(out.resolve("original.class"),original);
        if(a[0].equals("baseline")){verify(original);return;}
        ClassNode c=read(original);MethodNode method=target(c);int count=0;
        for(AbstractInsnNode n:method.instructions.toArray())if(offending(n)){
            InsnList replacement=new InsnList();replacement.add(new InsnNode(Opcodes.DUP));replacement.add(new InsnNode(Opcodes.ARRAYLENGTH));replacement.add(new MethodInsnNode(Opcodes.INVOKESTATIC,"java/util/Arrays","copyOf","([Ljava/lang/Object;I)[Ljava/lang/Object;",false));method.instructions.insertBefore(n,replacement);method.instructions.remove(n);count++;
        }
        if(count!=1)throw new AssertionError("Expected exactly one clone call, got "+count);
        ClassWriter w=new ClassWriter(ClassWriter.COMPUTE_MAXS);c.accept(w);byte[] patched=w.toByteArray();verify(patched);Files.write(out.resolve("patched.class"),patched);System.out.println("PATCHED exactly 1 call; no helper class added");
    }
}
