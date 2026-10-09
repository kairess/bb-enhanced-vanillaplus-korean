using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;

public static class MsgWrite
{
    // FMG version 2 (Bloodborne), little endian.
    public static byte[] WriteFmg(SortedDictionary<int, string> d)
    {
        var ids = new List<int>(d.Keys);
        var groups = new List<int[]>(); // offsetIndex, first, last
        for (int i = 0; i < ids.Count; i++)
        {
            if (groups.Count > 0 && groups[groups.Count - 1][2] + 1 == ids[i]) groups[groups.Count - 1][2] = ids[i];
            else groups.Add(new[] { i, ids[i], ids[i] });
        }
        int headerSize = 0x28;
        int groupsSize = groups.Count * 16;
        int offsetsStart = headerSize + groupsSize;
        int stringsStart = offsetsStart + ids.Count * 8;
        var strings = new MemoryStream();
        var offsets = new long[ids.Count];
        for (int i = 0; i < ids.Count; i++)
        {
            string t = d[ids[i]];
            if (t == null) { offsets[i] = 0; continue; }
            offsets[i] = stringsStart + strings.Length;
            byte[] s = Encoding.Unicode.GetBytes(t);
            strings.Write(s, 0, s.Length);
            strings.WriteByte(0); strings.WriteByte(0);
        }
        while ((stringsStart + strings.Length) % 4 != 0) strings.WriteByte(0);
        var o = new MemoryStream();
        var w = new BinaryWriter(o);
        w.Write((byte)0); w.Write((byte)0); w.Write((byte)2); w.Write((byte)0);
        w.Write(stringsStart + (int)strings.Length);
        w.Write((byte)1); w.Write((byte)0); w.Write((byte)0); w.Write((byte)0);
        w.Write(groups.Count);
        w.Write(ids.Count);
        w.Write(0xFF);
        w.Write((long)offsetsStart);
        w.Write(0L);
        foreach (var g in groups) { w.Write(g[0]); w.Write(g[1]); w.Write(g[2]); w.Write(0); }
        foreach (var off in offsets) w.Write(off);
        w.Write(strings.ToArray());
        w.Flush();
        return o.ToArray();
    }

    // Rebuild a BND4 using the template's header/entry table/names, replacing each file's data.
    public static byte[] WriteBnd4(byte[] template, Dictionary<string, byte[]> files)
    {
        int cnt = BitConverter.ToInt32(template, 0x0C);
        int es = (int)BitConverter.ToInt64(template, 0x20);
        int dataStart = int.MaxValue;
        for (int n = 0; n < cnt; n++) dataStart = Math.Min(dataStart, BitConverter.ToInt32(template, 0x40 + n * es + 0x18));
        var o = new MemoryStream();
        o.Write(template, 0, dataStart);
        byte[] head = o.ToArray();
        o = new MemoryStream();
        o.Write(head, 0, head.Length);
        for (int n = 0; n < cnt; n++)
        {
            int p = 0x40 + n * es;
            int no = BitConverter.ToInt32(template, p + 0x20);
            int e = no; while (template[e] != 0 || template[e + 1] != 0) e += 2;
            string nm = Path.GetFileName(Encoding.Unicode.GetString(template, no, e - no).Replace('\\', '/'));
            byte[] data = files[nm];
            while (o.Length % 16 != 0) o.WriteByte(0);
            long off = o.Length;
            o.Write(data, 0, data.Length);
            byte[] buf = o.GetBuffer();
            Array.Copy(BitConverter.GetBytes((long)data.Length), 0, buf, p + 0x08, 8);
            Array.Copy(BitConverter.GetBytes((long)data.Length), 0, buf, p + 0x10, 8);
            Array.Copy(BitConverter.GetBytes((int)off), 0, buf, p + 0x18, 4);
        }
        return o.ToArray();
    }

    static void PutBE(byte[] b, int at, int v) { b[at] = (byte)(v >> 24); b[at + 1] = (byte)(v >> 16); b[at + 2] = (byte)(v >> 8); b[at + 3] = (byte)v; }

    // DCX DFLT using the template file's 0x4C-byte header.
    public static byte[] WriteDcx(byte[] templateDcx, byte[] data)
    {
        var z = new MemoryStream();
        z.WriteByte(0x78); z.WriteByte(0xDA);
        using (var ds = new DeflateStream(z, CompressionLevel.Optimal, true)) ds.Write(data, 0, data.Length);
        uint a = 1, b2 = 0;
        foreach (byte x in data) { a = (a + x) % 65521; b2 = (b2 + a) % 65521; }
        uint adler = (b2 << 16) | a;
        z.WriteByte((byte)(adler >> 24)); z.WriteByte((byte)(adler >> 16)); z.WriteByte((byte)(adler >> 8)); z.WriteByte((byte)adler);
        byte[] zb = z.ToArray();
        byte[] head = new byte[0x4C];
        Array.Copy(templateDcx, head, 0x4C);
        PutBE(head, 0x1C, data.Length);
        PutBE(head, 0x20, zb.Length);
        var o = new MemoryStream();
        o.Write(head, 0, head.Length);
        o.Write(zb, 0, zb.Length);
        return o.ToArray();
    }

    // Write a parsed msgbnd back, using templatePath (a .msgbnd.dcx with the same FMG files) for the containers.
    public static void Save(string templatePath, Dictionary<string, SortedDictionary<int, string>> data, string outPath)
    {
        var files = new Dictionary<string, byte[]>();
        foreach (var kv in data) files[kv.Key] = WriteFmg(kv.Value);
        byte[] templateDcx = File.ReadAllBytes(templatePath);
        byte[] bnd = WriteBnd4(Msg.ReadDcx(templatePath), files);
        Directory.CreateDirectory(Path.GetDirectoryName(outPath));
        File.WriteAllBytes(outPath, WriteDcx(templateDcx, bnd));
    }

    // base: Korean vanilla. vanillaEng: English vanilla. layers: mod English msgbnds in load order.
    // Entries a layer adds or changes (vs English vanilla) override the Korean text.
    // Entries with no Korean text are always filled; entries that already have Korean text are
    // replaced only when that layer's applyChanges flag is set.
    public static string Merge(string baseKor, string vanillaEng, string[] layers, bool[] applyChanges, string outPath)
    {
        var kor = Msg.ReadMsgBnd(baseKor);
        var eng = Msg.ReadMsgBnd(vanillaEng);
        var log = new StringBuilder();
        for (int li = 0; li < layers.Length; li++)
        {
            string layer = layers[li];
            var mod = Msg.ReadMsgBnd(layer);
            foreach (var kv in mod)
            {
                if (!kor.ContainsKey(kv.Key)) { log.AppendLine("  skip unknown fmg " + kv.Key); continue; }
                var target = kor[kv.Key];
                SortedDictionary<int, string> van;
                eng.TryGetValue(kv.Key, out van);
                int added = 0, changed = 0, kept = 0;
                foreach (var e in kv.Value)
                {
                    string vanText = null;
                    bool inVan = van != null && van.TryGetValue(e.Key, out vanText);
                    if (inVan && vanText == e.Value) continue;
                    string korText;
                    bool hasKor = target.TryGetValue(e.Key, out korText) && !string.IsNullOrWhiteSpace(korText);
                    if (!hasKor) { if (!string.IsNullOrEmpty(e.Value)) { target[e.Key] = e.Value; added++; } }
                    else if (applyChanges[li]) { target[e.Key] = e.Value; changed++; }
                    else kept++;
                }
                if (added + changed + kept > 0) log.AppendLine(string.Format("  {0} <- {1}: filled {2}, replaced {3}, kept Korean {4}", kv.Key, Path.GetFileName(Path.GetDirectoryName(Path.GetDirectoryName(Path.GetDirectoryName(Path.GetDirectoryName(layer))))), added, changed, kept));
            }
        }
        var files = new Dictionary<string, byte[]>();
        foreach (var kv in kor) files[kv.Key] = WriteFmg(kv.Value);
        byte[] templateDcx = File.ReadAllBytes(baseKor);
        byte[] bnd = WriteBnd4(Msg.ReadDcx(baseKor), files);
        Directory.CreateDirectory(Path.GetDirectoryName(outPath));
        File.WriteAllBytes(outPath, WriteDcx(templateDcx, bnd));
        return log.ToString();
    }
}
