
# SignMin: Flutter PDF Digital Signing App

SignMin is a Flutter app for digitally signing PDF documents with a visible signature and X.509 certificate chain. It uses Syncfusion's PDF library and PointyCastle for cryptography.

## Features
- Pick a PDF and place a visible signature image
- Digitally sign using your own certificate and private key (PEM)
- Embeds the full certificate chain for trust
- (Optional) Timestamp Authority (TSA) support

## Getting Started
1. **Clone the repo:**
	```sh
	git clone https://github.com/your-username/sign_min.git
	cd sign_min
	```
2. **Install dependencies:**
	```sh
	flutter pub get
	```
3. **Add your keys/certs:**
	- Place your `privatekey.pem`, `cert.pem`, and any intermediate/root certs in the `assets/` folder.
	- Update `pubspec.yaml` to include these assets.
4. **Run the app:**
	```sh
	flutter run
	```

## Security
- **Never commit your private keys or certificates to version control!**
- The `.gitignore` is set up to exclude secrets and build artifacts.

## License
This project uses Syncfusion's PDF library. See their licensing terms.

---
For questions or contributions, open an issue or pull request.
