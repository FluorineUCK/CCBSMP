import java.nio.file.*;
import java.util.*;
import java.util.jar.*;
import java.lang.reflect.*;
import org.objectweb.asm.*;
import org.objectweb.asm.commons.*;

/** Runs the actual original/patched bytecode against instrumented Minecraft API doubles. */
public class TestRecovery {
    static final String TARGET = "dev/leo/sableplayerragdoll/mob/MobRagdollSourceRecovery";
    public static class Tag {}
    public static class CompoundTag extends Tag {
        final Map<String,Object> data = new HashMap<>();
        static int compounds;
        public boolean contains(String k, int type) { return type == 10 && data.get(k) instanceof CompoundTag; }
        public CompoundTag getCompound(String k) { compounds++; return data.get(k) instanceof CompoundTag t ? t : new CompoundTag(); }
        public boolean hasUUID(String k) { return data.get(k) instanceof UUID; }
        public UUID getUUID(String k) { return (UUID)data.get(k); }
        public void putUUID(String k, UUID v) { data.put(k,v); }
        public long getLong(String k) { return data.get(k) instanceof Number n ? n.longValue() : 0; }
        public void putLong(String k, long v) { data.put(k,v); }
        public boolean getBoolean(String k) { return Boolean.TRUE.equals(data.get(k)); }
        public void putBoolean(String k, boolean v) { data.put(k,v); }
        public Tag put(String k, Tag v) { return (Tag)data.put(k,v); }
        public void remove(String k) { data.remove(k); }
    }
    public static class Level {
        long time;
        static int reads;
        public long getGameTime() { reads++; return time; }
    }
    public static class LivingEntity {
        CompoundTag data = new CompoundTag();
        Level world = new Level();
        public boolean noPhysics, invisible;
        public CompoundTag getPersistentData() { return data; }
        public Level level() { return world; }
        public boolean isInvisible() { return invisible; }
        public void setInvisible(boolean b) { invisible=b; }
        public void refreshDimensions() {}
    }
    public static class Mob extends LivingEntity {
        boolean noAi;
        public boolean isNoAi() { return noAi; }
        public void setNoAi(boolean b) { noAi=b; }
    }
    static Class<?> load(byte[] bytes) {
        Map<String,String> names = new HashMap<>();
        for (String n : List.of("Tag","CompoundTag")) names.put("net/minecraft/nbt/"+n,"TestRecovery$"+n);
        for (String n : List.of("LivingEntity","Mob")) names.put("net/minecraft/world/entity/"+n,"TestRecovery$"+n);
        names.put("net/minecraft/world/level/Level","TestRecovery$Level");
        ClassWriter w = new ClassWriter(0);
        new ClassReader(bytes).accept(new ClassRemapper(w,new SimpleRemapper(names)),0);
        byte[] remapped=w.toByteArray();
        return new ClassLoader(TestRecovery.class.getClassLoader()) {
            Class<?> define() { return defineClass(null,remapped,0,remapped.length); }
        }.define();
    }
    static Object call(Class<?> c, String name, Class<?>[] types, Object... args) throws Exception {
        java.lang.reflect.Method m=c.getDeclaredMethod(name,types); m.setAccessible(true); return m.invoke(null,args);
    }
    static boolean active(Class<?> c, LivingEntity e) throws Exception {
        return (boolean)call(c,"active",new Class[]{LivingEntity.class},e);
    }
    static void check(boolean b, String message) { if (!b) throw new AssertionError(message); }
    public static void main(String[] args) throws Exception {
        byte[] original;
        try(JarFile j=new JarFile(args[0])) { original=j.getInputStream(j.getJarEntry(TARGET+".class")).readAllBytes(); }
        Class<?> base=load(original), patched=load(args.length==1 ? original : Files.readAllBytes(Path.of(args[1])));
        LivingEntity ordinary=new LivingEntity();
        check(!active(patched,ordinary),"ordinary entity inactive");
        check(Level.reads==0 && CompoundTag.compounds==0,
            "ordinary entity fast path must not read clock or getCompound: clock="+Level.reads+", compounds="+CompoundTag.compounds);
        System.out.println("PASS: ordinary entity skips clock and getCompound");
        String key="sable_player_ragdoll_mob_recovery", session="sable_player_ragdoll_session";
        UUID id=new UUID(1,2), other=new UUID(3,4);
        long[] times={Long.MIN_VALUE,-1,0,1,99,100,101,Long.MAX_VALUE};
        int cases=0;
        for(int kind=0;kind<5;kind++) for(int recordId=0;recordId<3;recordId++)
        for(int rootId=0;rootId<3;rootId++) for(long expiry:times) for(long now:times) {
            LivingEntity e=new LivingEntity(); CompoundTag record=new CompoundTag();
            if(recordId>0) record.putUUID("Session",recordId==1?id:other);
            if(rootId>0) e.data.putUUID(session,rootId==1?id:other);
            if(kind==1) e.data.data.put(key,"wrong tag type");
            if(kind>=2) e.data.put(key,record);
            if(kind==3) record.putLong("ExpiresAt",expiry);
            if(kind==4) record.data.put("Session","malformed UUID");
            e.world.time=now;
            check(active(base,e)==active(patched,e),"entity differential case "+cases);
            Class<?>[] signature={CompoundTag.class,long.class};
            check(call(base,"active",signature,e.data,now).equals(call(patched,"active",signature,e.data,now)),"NBT differential case "+cases);
            cases++;
        }
        for(Class<?> c:List.of(base,patched)) {
            Mob mob=new Mob();
            call(c,"begin",new Class[]{LivingEntity.class,UUID.class,long.class},mob,id,100L);
            mob.noPhysics=true; mob.invisible=true; mob.noAi=true;
            check(active(c,mob),"begin activates");
            mob.world.time=100; check(!active(c,mob),"expiry exact boundary");
            call(c,"extend",new Class[]{LivingEntity.class,long.class},mob,200L);
            check(active(c,mob),"extend reactivates");
            // Loaded entity and replaced persistent data need no cache invalidation.
            Mob reloaded=new Mob(); reloaded.data=mob.data; reloaded.world.time=100;
            check(active(c,reloaded),"loaded recovery record");
            reloaded.data.putUUID(session,other); check(!active(c,reloaded),"external session change");
            reloaded.data.putUUID(session,id); check(active(c,reloaded),"external session restored");
            call(c,"restore",new Class[]{LivingEntity.class},mob);
            check(!active(c,mob) && !mob.noPhysics && !mob.invisible && !mob.noAi,"restore original flags");
            call(c,"begin",new Class[]{LivingEntity.class,UUID.class,long.class},mob,other,300L);
            check(active(c,mob),"second session");
            call(c,"clear",new Class[]{LivingEntity.class},mob);
            check(!active(c,mob),"clear deactivates");
            mob.data=new CompoundTag(); check(!active(c,mob),"persistent data replacement");
        }
        System.out.println("PASS: "+cases+" differential states x two overloads; begin/expiry/extend/restore/clear/reload/external NBT changes");
    }
}
