# 🚀 Dev Setup for Backend Developers (macOS)

This repository provides an **interactive installation script** that sets up a complete backend development environment on **macOS** using **Homebrew**.  

The script automatically installs and configures:  
-  **Java 25** (Homebrew, Adoptium GA/EA, or OpenJDK EA fallback)  
-  **Maven** (build tool)  
-  **Git** (version control)  
-  **Docker Desktop** (container runtime)  
- ️ **Kubernetes CLI (kubectl)**  
-  **Minikube** (local Kubernetes cluster)  

---

## 📥 Installation

Clone this repository:

```bash
git clone https://github.com/Rapter1990/dev-setup-for-backend-developers.git
```

Go to Folder

```bash
cd dev-setup-for-backend-developers
```

Make the script executable and run it:

```bash
chmod +x install_tools.sh
./install_tools.sh
```

## 📜 Menu Options

When you run the script, you’ll see a menu like this:

```bash
---------------------------------------------
         🌟 Welcome to Dev Setup Menu 🌟
---------------------------------------------
1 - Install All (Java 25, Maven, Git, Docker, Kubernetes/kubectl, Minikube)
2 - Install Java 25
3 - Install Maven
4 - Install Docker
5 - Install Git
6 - Install Kubernetes (kubectl + Minikube)
7 - Verify installs
8 - Exit
---------------------------------------------
```

✅ Verification

You can check the installed versions anytime by choosing option 7 from the menu:

```bash
--- Versions ---
java:     openjdk version "25"
maven:    Apache Maven 3.9.x
git:      git version 2.xx
docker:   Docker version 23.xx
kubectl:  Client Version: v1.xx
minikube: minikube version: v1.xx
----------------
```

## 💡 Notes

- ️ The script is optimized for **macOS** with **Homebrew**.  
-  For Docker, make sure to **launch Docker Desktop once** so the engine is running.  
-  `JAVA_HOME` will be configured automatically when **Java 25** is installed.  
-  You can re-run the script anytime to **install missing components** or **verify installs**.  

---

## 🎯 Why use this?

Instead of manually installing and configuring each tool, this script ensures you get a  
**ready-to-code backend environment** with **consistent versions** — in just a few minutes.  

