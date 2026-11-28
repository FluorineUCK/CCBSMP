import java.nio.file.*;
import java.util.*;
import java.util.jar.*;
import org.objectweb.asm.*;
import org.objectweb.asm.tree.*;
import org.objectweb.asm.commons.*;

/** Execute the actual handler instructions, remapping only its two dependency types. */
public class TestSlots implements Opcodes {
    static final String TARGET="net/abraxator/moresnifferflowers/mixins/client/CreativeInventoryScreenMixin";
    public interface Operation { Object call(Object... args); }
    static ClassNode read(byte[] b) { ClassNode c=new ClassNode();new ClassReader(b).accept(c,0);return c; }
    static MethodNode method(ClassNode c) { return c.methods.stream().filter(m->m.name.equals("skipExtraSlots")).findFirst().orElseThrow(); }
    static byte[] original(String jar) throws Exception {
        try(JarFile j=new JarFile(jar)){return j.getInputStream(j.getJarEntry(TARGET+".class")).readAllBytes();}
    }
    static void verify(byte[] bytes) throws Exception {
        MethodNode m=method(read(bytes));
        // Keep local slot 0 ('this') by turning it into an unused static parameter.
        m.access=ACC_PUBLIC|ACC_STATIC;
        m.desc="(Ljava/lang/Object;"+m.desc.substring(1);
        m.signature=null;m.visibleAnnotations=null;m.invisibleAnnotations=null;
        ClassWriter w=new ClassWriter(ClassWriter.COMPUTE_MAXS);
        w.visit(V21,ACC_PUBLIC,"SlotProbe",null,"java/lang/Object",null);
        var remapper=new SimpleRemapper(Map.of("net/minecraft/core/NonNullList","java/util/List",
            "com/llamalad7/mixinextras/injector/wrapoperation/Operation","TestSlots$Operation"));
        m.accept(new ClassRemapper(w,remapper));w.visitEnd();byte[] probe=w.toByteArray();
        Class<?> cls=new ClassLoader(TestSlots.class.getClassLoader()) { Class<?> define(){return defineClass(null,probe,0,probe.length);} }.define();
        var handler=cls.getMethod("skipExtraSlots",Object.class,List.class,Operation.class);
        for(int size:new int[]{48,60,46,0,2,61,128,256}) {
            List<Object> slots=new ArrayList<>();for(int i=0;i<size;i++)slots.add(new Object());
            int[] calls={0};
            Operation op=args->{calls[0]++;if(args.length!=1||args[0]!=slots)throw new AssertionError("Operation argument changed");return slots.size();};
            int count=(int)handler.invoke(null,null,slots,op);
            if(count!=size)throw new AssertionError("Truncated inventory: server="+size+", wrappers="+count+", client including trash="+(count+1));
            if(calls[0]!=1)throw new AssertionError("Operation must be called exactly once");
            List<Object> creative=new ArrayList<>(slots.subList(0,count));creative.add(new Object());
            for(int i=0;i<size;i++)if(creative.get(i)!=slots.get(i))throw new AssertionError("Wrong slot identity: "+i);
            // Respect another wrapper's return value rather than bypassing the chain with slots.size().
            int chained=(int)handler.invoke(null,null,slots,(Operation)args->size+7);
            if(chained!=size+7)throw new AssertionError("Operation return value changed");
        }
        System.out.println("PASS: eight slot counts; 48->49 and 60->61; all server indices preserve identity; Operation argument/call count/result preserved");
    }
    public static void main(String[] args)throws Exception{verify(args.length==1?original(args[0]):Files.readAllBytes(Path.of(args[1])));}
}
