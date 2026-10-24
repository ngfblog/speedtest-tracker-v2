<?php

namespace App\Console\Commands;

use App\Models\Speedtest;
use Cache;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Log;

class PruneSpeedtestsCommand extends Command
{
    /**
     * Smallest retention accepted, so a typo cannot wipe the history.
     */
    public const MIN_DAYS = 30;

    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'speedtest:prune
                            {--dry-run : Only report how many speedtests would be deleted}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Delete speedtests older than HISTORY_DAYS (default 365)';

    /**
     * Execute the console command.
     *
     * @return int
     */
    public function handle()
    {
        $value = config('speedtest.history_days');

        if (filter_var($value, FILTER_VALIDATE_INT) === false || (int)$value < self::MIN_DAYS) {
            $msg = 'speedtest:prune refused: HISTORY_DAYS must be an integer >= ' . self::MIN_DAYS . ', got "' . $value . '"';
            Log::error($msg);
            $this->error($msg);

            return 1;
        }

        $days = (int)$value;
        $cutoff = Carbon::now()->subDays($days);
        $query = Speedtest::where('created_at', '<', $cutoff);

        if ($this->option('dry-run')) {
            $count = $query->count();
            $msg = 'speedtest:prune dry run: ' . $count . ' speedtests older than ' . $days . ' days (before ' . $cutoff . ') would be deleted';
            Log::info($msg);
            $this->info($msg);

            return 0;
        }

        $count = $query->delete();

        if ($count > 0) {
            // Graph and statistics data is cached per number of days
            Cache::flush();
        }

        $msg = 'speedtest:prune deleted ' . $count . ' speedtests older than ' . $days . ' days (before ' . $cutoff . ')';
        Log::info($msg);
        $this->info($msg);

        return 0;
    }
}
