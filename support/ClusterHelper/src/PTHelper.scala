import scala.io.Source
import scala.collection.mutable.ListBuffer

object PTHelper {

  // Speedup over splitFast
  def oneFactor(s: String): String = {
    val delim = s.indexOf("|")
    if (delim == -1) {
      return s
    }
    return s.substring(0, delim)
  }

  // Speedup over split
  def splitFast(s: String, delim: String): Array[String] = {
    val begin = ListBuffer[Int]()
    val end = ListBuffer[Int]()
    var b = 0
    var e = 0
    while (e != -1) {
      e = s.indexOf(delim, b)
      begin += b
      if (e == -1) {
        end += s.length
      } else {
        end += e
      }
      b = e + delim.length
    }
    val res = new Array[String](begin.length)
    val bi = begin.iterator
    val ei = end.iterator
    for (i <- 0 to begin.length - 1) {
      res(i) = s.substring(bi.next, ei.next)
    }
    return res
  }

  def add(sPaths: String, tPaths: String) = {
    // Source clusters
    val sClusters = Source.fromFile(sPaths).getLines.map(_.split("\\s+")).map(x => (x(1), x(0))).toMap
    // Target clusters
    val tClusters = Source.fromFile(tPaths).getLines.map(_.split("\\s+")).map(x => (x(1), x(0))).toMap
    // Scan PT
    for (line <- Source.stdin.getLines) {
      val fields = splitFast(line, " ||| ")
      // Handle factored input by using first factor
      val sClustered = splitFast(fields(0), " ").map(oneFactor).map(sClusters).mkString(" ")
      val tClustered = splitFast(fields(1), " ").map(oneFactor).map(tClusters).mkString(" ")
      println("%s ||| %s ||| %s".format(sClustered, tClustered, line))
    }
  }

  def merge(augPT: String, clusterPT: String) = {
    val augLines = Source.fromFile(augPT).getLines
    val clusterLines = Source.fromFile(clusterPT).getLines
    var curPhrase = ("", "")
    var curFeatures = ""
    for (augLine <- augLines) {
      val fields = splitFast(augLine, " ||| ")
      val phrase = (fields(0), fields(1))
      // Mismatch: advance
      if (curPhrase != phrase) {
        val clusterFields = splitFast(clusterLines.next, " ||| ")
        curPhrase = (clusterFields(0), clusterFields(1))
        curFeatures = clusterFields(2)
      }
      // Now phrases guaranteed to match
      // Merge features
      if (fields.length > 5) {
        // Phrase table
        println("%s %s ||| %s".format(fields.take(5).mkString(" ||| "), curFeatures, fields.takeRight(fields.length - 5).mkString(" ||| ")))
      } else {
        // Reordering table
        println("%s %s".format(augLine.trim, curFeatures))
      }
    }
  }

  def rm = {
    for (fields <- Source.stdin.getLines.map(splitFast(_, " ||| "))) {
      println(fields.takeRight(fields.length - 2).mkString(" ||| "))
    }
  }

  def main(args: Array[String]) = {
    if (args.length == 0) {
      System.err.println("")
      System.err.println("Add cluster features to surface phrase table (or reordering table)")
      System.err.println("")
      System.err.println("zcat surface.gz |PTHelper add srcPaths tgtPaths |LC_ALL=C sort -T. -S8G --parallel=8 |gzip >surface-aug.gz")
      System.err.println("PTHelper merge <(zcat surface-aug.gz) <(zcat cluster.gz) |gzip >merged-aug.gz")
      System.err.println("zcat merged-aug.gz |PTHelper rm |LC_ALL=C sort -T. -S8G --parallel=8 |gzip >merged.gz")
      System.err.println("")
      System.exit(2)
    }

    if (args(0) == "add") {
      add(args(1), args(2))
    } else if (args(0) == "merge") {
      merge(args(1), args(2))
    } else if (args(0) == "rm") {
      rm
    }
  }
}