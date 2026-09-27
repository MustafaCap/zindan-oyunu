// ApkSignerLite — Android SDK'nın apksigner komutunun Godot'nun kullandığı kadarı (sign, verify, --version).
// Android SDK'nın indirilemediği ortamlarda (bulut oturumu) APK'yı imzalamak için; Maven Central'daki apksig
// kütüphanesiyle çalışır. Normal bir bilgisayarda Android SDK'nın kendi apksigner'ı kullanılır, buna gerek yoktur.
// Kurulum: tools/android/setup_sdk_lite.sh
import com.android.apksig.ApkSigner;
import com.android.apksig.ApkVerifier;

import java.io.File;
import java.io.FileInputStream;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.cert.Certificate;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.List;

public class ApkSignerLite {
	public static void main(String[] args) throws Throwable {
		if (args.length == 0 || args[0].equals("--version") || args[0].equals("version")) {
			System.out.println("0.9-lite");
			return;
		}
		switch (args[0]) {
			case "sign" -> System.exit(sign(args));
			case "verify" -> System.exit(verify(args));
			default -> {
				System.err.println("Bilinmeyen komut: " + args[0]);
				System.exit(2);
			}
		}
	}

	static String pass(String v) {
		return v.startsWith("pass:") ? v.substring(5) : v;
	}

	static int sign(String[] args) throws Throwable {
		String ks = null, ksPass = "", alias = null, keyPass = null, out = null, apk = null;
		int minSdk = 24;
		for (int i = 1; i < args.length; i++) {
			switch (args[i]) {
				case "--ks" -> ks = args[++i];
				case "--ks-pass" -> ksPass = pass(args[++i]);
				case "--ks-key-alias" -> alias = args[++i];
				case "--key-pass" -> keyPass = pass(args[++i]);
				case "--out" -> out = args[++i];
				case "--min-sdk-version" -> minSdk = Integer.parseInt(args[++i]);
				case "--verbose", "-v" -> { }
				default -> {
					if (args[i].startsWith("--")) {
						i++;  // bilinmeyen seçenek ve değeri (ör. --v4-signing-enabled false)
					} else {
						apk = args[i];
					}
				}
			}
		}
		if (ks == null || apk == null) {
			System.err.println("Kullanım: sign --ks KS --ks-pass pass:P --ks-key-alias A [--out OUT] APK");
			return 2;
		}
		KeyStore store = KeyStore.getInstance(KeyStore.getDefaultType());
		try (FileInputStream in = new FileInputStream(ks)) {
			store.load(in, ksPass.toCharArray());
		}
		if (alias == null) {
			alias = store.aliases().nextElement();
		}
		PrivateKey key = (PrivateKey) store.getKey(alias, (keyPass != null ? keyPass : ksPass).toCharArray());
		List<X509Certificate> certs = new ArrayList<>();
		for (Certificate c : store.getCertificateChain(alias)) {
			certs.add((X509Certificate) c);
		}
		ApkSigner.SignerConfig cfg = new ApkSigner.SignerConfig.Builder("CERT", key, certs).build();
		File input = new File(apk);
		File tmp = File.createTempFile("signed", ".apk", input.getAbsoluteFile().getParentFile());
		try {
			new ApkSigner.Builder(List.of(cfg))
				.setInputApk(input)
				.setOutputApk(tmp)
				.setMinSdkVersion(minSdk)
				.setV1SigningEnabled(false)  // v1 (JAR) imzası eski apksig'de yeni JDK'larla çalışmıyor; Android 7+ için v2 yeter
				.setV2SigningEnabled(true)
				.build()
				.sign();
		} catch (Throwable e) {
			tmp.delete();
			throw e;
		}
		Files.move(tmp.toPath(), new File(out != null ? out : apk).toPath(), StandardCopyOption.REPLACE_EXISTING);
		System.out.println("Signed");
		return 0;
	}

	static int verify(String[] args) throws Exception {
		String apk = null;
		for (int i = 1; i < args.length; i++) {
			if (!args[i].startsWith("-")) {
				apk = args[i];
			}
		}
		ApkVerifier.Result r = new ApkVerifier.Builder(new File(apk)).setMinCheckedPlatformVersion(24).build().verify();
		System.out.println("Verifies: " + r.isVerified());
		System.out.println("Verified using v1 scheme (JAR signing): " + r.isVerifiedUsingV1Scheme());
		System.out.println("Verified using v2 scheme (APK Signature Scheme v2): " + r.isVerifiedUsingV2Scheme());
		for (ApkVerifier.IssueWithParams e : r.getErrors()) {
			System.err.println("ERROR: " + e);
		}
		return r.isVerified() ? 0 : 1;
	}
}
