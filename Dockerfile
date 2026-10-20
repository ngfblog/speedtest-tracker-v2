FROM henrywhitaker3/speedtest-tracker

# Install modern Node.js (Node 20) via Nodesource instead of legacy apk/apt
RUN apt-get update && apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /site

# Copy fixed JS source files (DD/MM/YY date format)
COPY src/HistoryGraph.js /site/resources/js/components/Graphics/HistoryGraph.js
COPY src/TableRow.js /site/resources/js/components/Graphics/TableRow.js

# Build the JS bundle with modern Node
RUN npm install && npm run production

# Copy fixed PHP controller ($days passed correctly to actions)
COPY src/HomepageDataController.php /site/app/Http/Controllers/HomepageDataController.php
