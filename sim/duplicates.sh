grep -r OUT_DEBUG ../sw | sed -n 's/.*OUT_DEBUG.*=.\(.*\).*/\1/p' | sort
