      </div>
      <div class="ad-network">
	<img src="<?php $files = array_map(fn($p) => substr($p, strlen(__DIR__.'/html')), glob(__DIR__ . "/html/assets/ads/*.png")); echo $files[array_rand($files)]; ?>">
      </div>
    </div>
  </body>
</html>
