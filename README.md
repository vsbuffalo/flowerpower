## flowerpower — R API to Parrot's Flower Power Sensor

An R API to Parrot's awesome
[Flower Power sensor](http://www.parrot.com/usa/products/flower-power/). This is
still in **alpha** — use with caution.

    > fp <- flowerpower(user, pass, id, secret)
    > get_locations(fp) # get location IDs
    > s <- get_samples(fp, location='1W2zIGfgEF14220_YOURLOCATIONKEY')
	> head(s)
           capture_ts par_umole_m2s air_temperature_celsius vwc_percent
    1 2015-03-10 21:49:00     12.607764                30.45476    17.04505
    2 2015-03-10 22:04:00     11.928668                29.37226    16.63505
    3 2015-03-10 22:19:00      8.715568                28.45192    16.44611
    4 2015-03-10 22:34:00     11.429752                28.15554    15.81059
    5 2015-03-10 22:49:00      7.567640                28.86598    16.66856
    6 2015-03-10 23:04:00      7.066480                28.31073    16.91436


## Design

An R6 class stores state and lower-level methods for getting data from the
server, and higher-level S3 methods call these methods and reshape
results. Users interact with these higher-level functions, but I leave the
object methods public for developers that want to do their own hacking.

## Todo

- Refresh auth token.




