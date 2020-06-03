function ConvertTo-ByteUnits
	{
	[CmdletBinding()]
	Param (
		[Parameter (
			Position = 0,
			Mandatory)]
			[int64]
			$InputObject
		)

	begin {}

	process
		{
		$Sign = [math]::Sign($InputObject)
		$InputObject = [math]::Abs($InputObject)
		switch ($InputObject)
			{
			{$_ -ge 1TB }
				{$Unit = 'TB'; break}
			{$_ -ge 1GB }
				{$Unit = 'GB'; break}
			{$_ -ge 1MB }
				{$Unit = 'MB'; break}
			{$_ -ge 1KB }
				{$Unit = 'KB'; break}
			default
				{$Unit = 'B'}
			}

		if ($Unit -ne 'B')
			{
			'{0:N2} {1}' -f ($Sign * $InputObject / "1$Unit"), $Unit
			}
			else
			{
			'{0} {1}' -f ($Sign * $InputObject), $Unit
			}

		} # end >> process

	end {}

	} # end >> function