ARG BAZARR_VERSION
FROM linuxserver/bazarr:${BAZARR_VERSION} AS bazarr_base

# Install https://github.com/smacke/ffsubsync/ for subtitle syncing, and dependencies
# Add the follwing in Bazarr as a post-processing command:
# /usr/bin/ffsubsync -i "{{subtitles}}" -o "{{subtitles}}" "{{episode}}" >>/tmp/subsync_log 2>&1
RUN apk add ffmpeg py3-scipy g++ openblas py3-numpy-dev git python3-dev py3-pip && \
    pip3 install cython git+https://github.com/smacke/ffsubsync@latest
