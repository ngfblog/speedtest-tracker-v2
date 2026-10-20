FROM henrywhitaker3/speedtest-tracker

RUN apt-get update && apt-get remove -y nodejs libnode-dev libnode72 || true && \
    apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /site

COPY src/HistoryGraph.js /site/resources/js/components/Graphics/HistoryGraph.js
COPY src/TableRow.js /site/resources/js/components/Graphics/TableRow.js

RUN npm install && npm run production

COPY src/HomepageDataController.php /site/app/Http/Controllers/HomepageDataController.php
