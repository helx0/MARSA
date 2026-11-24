package org.gradle.wrapper;

import java.io.*;
import java.net.URI;
import java.nio.file.*;
import java.util.*;
import java.util.zip.*;

/** Minimal independent Gradle distribution launcher. Uses HTTPS distributionUrl from gradle-wrapper.properties.
 *  A standard Gradle wrapper jar can replace this bootstrap by running `gradle wrapper`.
 */
public final class GradleWrapperMain {
  public static void main(String[] args) throws Exception {
    File root = new File(System.getProperty("user.dir"));
    File file = new File(root, "gradle/wrapper/gradle-wrapper.properties");
    if (!file.isFile()) throw new IllegalStateException("Run from android/ directory");
    Properties p = new Properties();
    try (InputStream in = new FileInputStream(file)) { p.load(in); }
    String distribution = p.getProperty("distributionUrl");
    if (!distribution.startsWith("https://services.gradle.org/distributions/"))
      throw new SecurityException("Unexpected Gradle distribution source");
    String base = distribution.substring(distribution.lastIndexOf('/') + 1).replace("-bin.zip", "").replace("-all.zip", "");
    File distHome = new File(System.getProperty("user.home"), ".gradle/marsa-wrapper/" + base);
    File gradle = new File(distHome, "bin/gradle" + (System.getProperty("os.name").toLowerCase().contains("win") ? ".bat" : ""));
    if (!gradle.exists()) {
      Files.createDirectories(distHome.toPath().getParent());
      Path zipFile = Files.createTempFile("marsa-gradle-", ".zip");
      try {
        System.out.println("Downloading official Gradle distribution: " + distribution);
        try (InputStream input = URI.create(distribution).toURL().openStream()) { Files.copy(input, zipFile, StandardCopyOption.REPLACE_EXISTING); }
        File tempDir = new File(distHome.getParentFile(), base + ".unpacking");
        tempDir.mkdirs();
        try (ZipInputStream zis = new ZipInputStream(new FileInputStream(zipFile.toFile()))) {
          ZipEntry entry;
          while ((entry = zis.getNextEntry()) != null) {
            Path destination = tempDir.toPath().resolve(entry.getName()).normalize();
            if (!destination.startsWith(tempDir.toPath())) throw new SecurityException("Invalid zip path");
            if (entry.isDirectory()) Files.createDirectories(destination);
            else { Files.createDirectories(destination.getParent()); Files.copy(zis, destination, StandardCopyOption.REPLACE_EXISTING); }
          }
        }
        File unpacked = new File(tempDir, base);
        if (!unpacked.isDirectory()) throw new IOException("Invalid Gradle distribution");
        Files.move(unpacked.toPath(), distHome.toPath(), StandardCopyOption.REPLACE_EXISTING);
      } finally { Files.deleteIfExists(zipFile); }
    }
    gradle.setExecutable(true);
    List<String> command = new ArrayList<>();
    command.add(gradle.getAbsolutePath()); Collections.addAll(command, args);
    Process p1 = new ProcessBuilder(command).directory(root).inheritIO().start();
    System.exit(p1.waitFor());
  }
}
