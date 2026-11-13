package dev.deang.flagtool;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;
import java.util.TreeMap;

/**
 * Sets boolean flags to true in a Play services shared flag file
 * (files/phenotype/shared/<group>.pb), keeping its order: Play services looks flags up by
 * position, so entries tacked on at the end are ignored.
 *
 * Run with app_process:  CLASSPATH=flagtool.dex app_process /system/bin dev.deang.flagtool.Main FILE ID... [-NAME...]
 * (ID sets a boolean to true, ID=N sets a long to N; -NAME removes an entry with that name.)
 * Prints "unchanged" or "updated"; exits 1 on an unreadable file (and leaves it untouched).
 *
 * File layout (protobuf): repeated field 5 = flag { 1: name, 3: bool | 2: long | 6: bytes ... }.
 * Named flags come first in name order, then numeric IDs in numeric order.
 */
public final class Main {
    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            System.err.println("usage: Main FILE ID...");
            System.exit(2);
        }
        File f = new File(args[0]);
        byte[] d = Files.readAllBytes(f.toPath());

        List<byte[]> fields = new ArrayList<>();
        List<Integer> numbers = new ArrayList<>();
        int i = 0;
        try {
            while (i < d.length) {
                int start = i;
                long[] r = varint(d, i);
                int field = (int) (r[0] >>> 3), type = (int) (r[0] & 7);
                i = (int) r[1];
                if (type == 0) {
                    i = (int) varint(d, i)[1];
                } else if (type == 2) {
                    long[] l = varint(d, i);
                    i = (int) l[1] + (int) l[0];
                } else if (type == 1) {
                    i += 8;
                } else if (type == 5) {
                    i += 4;
                } else {
                    throw new IllegalStateException("wire type " + type);
                }
                if (i > d.length) throw new IllegalStateException("truncated");
                fields.add(slice(d, start, i));
                numbers.add(field);
            }
        } catch (RuntimeException e) {
            System.err.println("unreadable flag file: " + e);
            System.exit(1);
        }

        // Wanted flags, by numeric ID; drop existing entries for them so each ends up true once.
        // Arguments: numeric IDs to set true, and "-NAME" for entries to remove.
        TreeMap<Long, String> want = new TreeMap<>();
        java.util.HashMap<String, Long> longs = new java.util.HashMap<>();
        List<String> drop = new ArrayList<>();
        for (int a = 1; a < args.length; a++) {
            String arg = args[a];
            if (arg.startsWith("-")) { drop.add(arg.substring(1)); continue; }
            int eq = arg.indexOf('=');
            if (eq > 0) {
                longs.put(arg.substring(0, eq), Long.parseLong(arg.substring(eq + 1)));
                arg = arg.substring(0, eq);
            }
            want.put(Long.parseLong(arg), arg);
        }
        boolean already = true;
        for (String id : want.values()) already &= hasValue(fields, numbers, id, longs.get(id));
        for (int k = 0; k < fields.size(); k++) {
            if (numbers.get(k) == 5 && drop.contains(flagName(fields.get(k)))) already = false;
        }
        if (already) {
            System.out.println("unchanged");
            return;
        }

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        List<String> pending = new ArrayList<>(want.values());
        for (int k = 0; k < fields.size(); k++) {
            byte[] raw = fields.get(k);
            int field = numbers.get(k);
            if (field == 5) {
                String name = flagName(raw);
                if (want.containsValue(name) || drop.contains(name)) continue; // rewritten / removed
                if (isNumber(name)) {
                    while (!pending.isEmpty() && Long.parseLong(name) > Long.parseLong(pending.get(0))) {
                        out.write(flag(pending.remove(0), longs));
                    }
                }
            } else if (field > 5) {
                while (!pending.isEmpty()) out.write(flag(pending.remove(0), longs));
            }
            out.write(raw);
        }
        while (!pending.isEmpty()) out.write(flag(pending.remove(0), longs));

        File tmp = new File(f.getPath() + ".flagtool");
        try (FileOutputStream o = new FileOutputStream(tmp)) {
            o.write(out.toByteArray());
            o.getFD().sync();
        }
        if (!tmp.renameTo(f)) throw new IllegalStateException("rename failed");
        System.out.println("updated");
    }

    /** True when flag id exists as boolean true (want == null) or as long == want. */
    private static boolean hasValue(List<byte[]> fields, List<Integer> numbers, String id, Long want) {
        for (int k = 0; k < fields.size(); k++) {
            if (numbers.get(k) != 5 || !id.equals(flagName(fields.get(k)))) continue;
            byte[] body = body(fields.get(k));
            int j = 0;
            while (j < body.length) {
                long[] r = varint(body, j);
                int field = (int) (r[0] >>> 3), type = (int) (r[0] & 7);
                j = (int) r[1];
                if (type == 0) {
                    long[] v = varint(body, j);
                    if (want == null && field == 3) return v[0] == 1;
                    if (want != null && field == 2) return v[0] == want;
                    j = (int) v[1];
                } else if (type == 2) {
                    long[] l = varint(body, j);
                    j = (int) l[1] + (int) l[0];
                } else if (type == 1) {
                    j += 8;
                } else {
                    j += 4;
                }
            }
            return false;
        }
        return false;
    }

    /** Flag entry: { 1: name, 3: true } or { 1: name, 2: long }. */
    private static byte[] flag(String name, java.util.Map<String, Long> longs) {
        byte[] n = name.getBytes(StandardCharsets.US_ASCII);
        ByteArrayOutputStream b = new ByteArrayOutputStream();
        b.write(0x0a);
        writeVarint(b, n.length);
        b.write(n, 0, n.length);
        Long v = longs.get(name);
        if (v == null) {
            b.write(0x18);
            b.write(0x01);
        } else {
            b.write(0x10);
            writeVarint64(b, v);
        }
        byte[] body = b.toByteArray();
        ByteArrayOutputStream e = new ByteArrayOutputStream();
        e.write(0x2a);
        writeVarint(e, body.length);
        e.write(body, 0, body.length);
        return e.toByteArray();
    }

    private static byte[] body(byte[] raw) {
        long[] k = varint(raw, 0);
        long[] l = varint(raw, (int) k[1]);
        return slice(raw, (int) l[1], (int) l[1] + (int) l[0]);
    }

    private static String flagName(byte[] raw) {
        byte[] b = body(raw);
        long[] k = varint(b, 0);
        if ((k[0] >>> 3) != 1 || (k[0] & 7) != 2) return "";
        long[] l = varint(b, (int) k[1]);
        return new String(b, (int) l[1], (int) l[0], StandardCharsets.US_ASCII);
    }

    private static boolean isNumber(String s) {
        if (s.isEmpty() || s.length() > 18) return false;
        for (int c = 0; c < s.length(); c++) if (!Character.isDigit(s.charAt(c))) return false;
        return true;
    }

    /** Returns {value, next index}. */
    private static long[] varint(byte[] b, int i) {
        long r = 0;
        int s = 0;
        while (true) {
            if (i >= b.length || s > 63) throw new IllegalStateException("bad varint");
            int x = b[i++] & 0xff;
            r |= (long) (x & 0x7f) << s;
            s += 7;
            if (x < 0x80) return new long[]{r, i};
        }
    }

    private static void writeVarint(ByteArrayOutputStream o, int n) {
        while (true) {
            int x = n & 0x7f;
            n >>>= 7;
            if (n != 0) {
                o.write(x | 0x80);
            } else {
                o.write(x);
                return;
            }
        }
    }

    private static void writeVarint64(ByteArrayOutputStream o, long n) {
        while (true) {
            int x = (int) (n & 0x7f);
            n >>>= 7;
            if (n != 0) {
                o.write(x | 0x80);
            } else {
                o.write(x);
                return;
            }
        }
    }

    private static byte[] slice(byte[] b, int from, int to) {
        byte[] o = new byte[to - from];
        System.arraycopy(b, from, o, 0, o.length);
        return o;
    }
}
