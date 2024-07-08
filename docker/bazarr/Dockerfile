ARG BAZARR_VERSION
FROM linuxserver/bazarr:${BAZARR_VERSION} AS bazarr_base

# Install https://github.com/smacke/ffsubsync/ for subtitle syncing, and dependencies
# Add the following to Bazarr as a post-processing command:
# /usr/bin/ffsubsync -i "{{subtitles}}" -o "{{subtitles}}" "{{episode}}" >>/tmp/subsync_log 2>&1;
RUN apk add ffmpeg py3-scipy g++ openblas py3-numpy-dev git python3-dev py3-pip && \
    pip3 install cython git+https://github.com/smacke/ffsubsync@latest

# Download https://github.com/KBlixt/subcleaner to clean ads from subtitles
# Add the following to Bazarr as a post-processing command:
# python3 /opt/subcleaner/subcleaner.py "{{subtitles}}" -s;
# Also downloads https://github.com/TheCaptain989/bazarr-cleansubs to remove scene brandings from subtitles
# Add the following to Bazarr as a post-processing command:
# /opt/cleansubs.sh -f "{{subtitles}}";
RUN cd /opt/ && \
    git clone https://github.com/KBlixt/subcleaner.git && \
    wget -O /opt/cleansubs.sh https://raw.githubusercontent.com/TheCaptain989/bazarr-cleansubs/master/cleansubs.sh
