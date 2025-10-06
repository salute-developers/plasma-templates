#FROM eclipse-temurin:17-jdk-jammy
FROM saschpe/android-sdk:34-jdk17.0.12_7

# Аргумент для выбора compose/xml
ARG COMPOSE=false
ENV COMPOSE=${COMPOSE}

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git bash unzip \
    && rm -rf /var/lib/apt/lists/*


# Копируем проект и скрипты
COPY . /src/android-template
COPY scripts/main.sh /usr/local/bin/main.sh
COPY scripts/evaluate.sh /usr/local/bin/evaluate.sh
COPY scripts/publish.sh /usr/local/bin/publish.sh
COPY scripts/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/main.sh /usr/local/bin/evaluate.sh /usr/local/bin/publish.sh /usr/local/bin/init.sh

## ---- Android SDK (commandline-tools) ----
# Предустанавливаем нужные компоненты SDK
RUN /opt/android-sdk-linux/cmdline-tools/latest/bin/sdkmanager --version && \
    yes | /opt/android-sdk-linux/cmdline-tools/latest/bin/sdkmanager --licenses && \
    /opt/android-sdk-linux/cmdline-tools/latest/bin/sdkmanager \
      "platform-tools" \
      "platforms;android-33" \
      "build-tools;33.0.1"

# Node.js + Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y nodejs \
 && npm install -g yarn

# Gradle cache location (kept across layers and used at runtime)
ENV GRADLE_USER_HOME=/opt/gradle

# Pre-fetch Gradle wrapper distribution to speed up first run
# Copy only the wrapper bits so this layer is cacheable unless wrapper version changes
COPY gradle /tmp/gradle
COPY gradlew /tmp/gradlew
RUN chmod +x /tmp/gradlew \
 && cd /tmp \
 && ./gradlew --version --no-daemon || true \
 && rm -rf /tmp/gradle /tmp/gradlew

# Sanity check: bake Java details into the image build logs
RUN bash -lc 'echo "JAVA_HOME=$JAVA_HOME" && which java && readlink -f $(which java) && java -version'

# Запускаем скрипт при сборке
RUN /usr/local/bin/init.sh

WORKDIR /work

ENTRYPOINT ["/usr/local/bin/main.sh"]