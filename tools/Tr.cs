using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

public static class Tr
{
    public static string Norm(string s)
    {
        s = s.ToLowerInvariant();
        s = Regex.Replace(s, @"\bamongst\b", "among");
        s = Regex.Replace(s, @"\b(armour|colour|honour|favour|behaviour|rumour|vigour|valour|odour|splendour|harbour|labour|endeavour)", m => m.Value.Replace("our", "or"));
        s = Regex.Replace(s, @"mould", "mold");
        s = Regex.Replace(s, @"foetid", "fetid");
        s = Regex.Replace(s, @"grey", "gray");
        s = Regex.Replace(s, @"jewelled", "jeweled");
        s = Regex.Replace(s, @"reveller", "reveler");
        s = Regex.Replace(s, @"co-operat", "cooperat");
        s = Regex.Replace(s, @"backwards", "backward");
        s = Regex.Replace(s, @"[^a-z0-9]+", "");
        return s;
    }

    static HashSet<string> Tokens(string s)
    {
        return new HashSet<string>(Regex.Split(s.ToLowerInvariant(), @"[^a-z0-9']+").Where(t => t.Length > 0));
    }

    public static double Jaccard(HashSet<string> a, HashSet<string> b)
    {
        int inter = a.Count(x => b.Contains(x));
        int uni = a.Count + b.Count - inter;
        return uni == 0 ? 0 : (double)inter / uni;
    }

    // Returns best (score, englishKey) among candidates.
    public static object[] Best(string text, List<string> candidates)
    {
        var ta = Tokens(text);
        double best = 0; string bk = null;
        foreach (var c in candidates)
        {
            var tb = Tokens(c);
            if (Math.Abs(ta.Count - tb.Count) > Math.Max(ta.Count, tb.Count) * 0.3) continue;
            double j = Jaccard(ta, tb);
            if (j > best) { best = j; bk = c; }
        }
        return new object[] { best, bk };
    }
}
