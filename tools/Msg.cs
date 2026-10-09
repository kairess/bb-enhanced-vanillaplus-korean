using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;

public static class Msg
{
    public static byte[] ReadDcx(string path)
    {
        byte[] b = File.ReadAllBytes(path);
        int i = -1;
        for (int k = 0; k + 4 <= b.Length; k++)
            if (b[k] == 'D' && b[k + 1] == 'C' && b[k + 2] == 'A' && b[k + 3] == 0) { i = k; break; }
        if (i < 0) throw new Exception("no DCA: " + path);
        int start = i + 8 + 2;
        using (var ms = new MemoryStream(b, start, b.Length - start))
        using (var ds = new DeflateStream(ms, CompressionMode.Decompress))
        using (var o = new MemoryStream()) { ds.CopyTo(o); return o.ToArray(); }
    }

    // Returns fmg file name -> (id -> text)
    public static Dictionary<string, SortedDictionary<int, string>> ReadMsgBnd(string path)
    {
        byte[] b = ReadDcx(path);
        var r = new Dictionary<string, SortedDictionary<int, string>>();
        if (Encoding.ASCII.GetString(b, 0, 4) == "BND4")
        {
            int cnt = BitConverter.ToInt32(b, 0x0C);
            int es = (int)BitConverter.ToInt64(b, 0x20);
            for (int n = 0; n < cnt; n++)
            {
                int p = 0x40 + n * es;
                int off = BitConverter.ToInt32(b, p + 0x18);
                int no = BitConverter.ToInt32(b, p + 0x20);
                int e = no; while (b[e] != 0 || b[e + 1] != 0) e += 2;
                string nm = Path.GetFileName(Encoding.Unicode.GetString(b, no, e - no).Replace('\\', '/'));
                r[nm] = ReadFmg(b, off);
            }
            return r;
        }
        if (Encoding.ASCII.GetString(b, 0, 4) != "BND3") throw new Exception("not BND3: " + path);
        byte fmt = b[0x0C];
        int count = BitConverter.ToInt32(b, 0x10);
        int esize = 12;
        if ((fmt & 0x02) != 0) esize += 4;
        if ((fmt & 0x0C) != 0) esize += 4;
        if ((fmt & 0x20) != 0) esize += 4;
        for (int n = 0; n < count; n++)
        {
            int p = 0x20 + n * esize;
            int size = BitConverter.ToInt32(b, p + 4);
            int off = BitConverter.ToInt32(b, p + 8);
            int q = p + 12;
            if ((fmt & 0x02) != 0) q += 4;
            string name = "#" + n;
            if ((fmt & 0x0C) != 0)
            {
                int no = BitConverter.ToInt32(b, q);
                int e = no; while (b[e] != 0) e++;
                name = Path.GetFileName(Encoding.ASCII.GetString(b, no, e - no).Replace('\\', '/'));
            }
            r[name] = ReadFmg(b, off);
        }
        return r;
    }

    static SortedDictionary<int, string> ReadFmg(byte[] b, int baseOff)
    {
        var d = new SortedDictionary<int, string>();
        bool v2 = b[baseOff + 2] == 2;
        int groups = BitConverter.ToInt32(b, baseOff + 0x0C);
        int offs = v2 ? (int)BitConverter.ToInt64(b, baseOff + 0x18) : BitConverter.ToInt32(b, baseOff + 0x14);
        for (int g = 0; g < groups; g++)
        {
            int p = v2 ? baseOff + 0x28 + g * 16 : baseOff + 0x1C + g * 12;
            int idx = BitConverter.ToInt32(b, p);
            int first = BitConverter.ToInt32(b, p + 4);
            int last = BitConverter.ToInt32(b, p + 8);
            for (int id = first; id <= last; id++)
            {
                int so = v2 ? (int)BitConverter.ToInt64(b, baseOff + offs + (idx + id - first) * 8)
                            : BitConverter.ToInt32(b, baseOff + offs + (idx + id - first) * 4);
                if (so == 0) { d[id] = null; continue; }
                int s = baseOff + so, e = s;
                while (b[e] != 0 || b[e + 1] != 0) e += 2;
                d[id] = Encoding.Unicode.GetString(b, s, e - s);
            }
        }
        return d;
    }
}
