CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `bcchousing` (
            `charidentifier` varchar(50) NOT NULL,
            `house_coords` LONGTEXT NOT NULL,
            `house_radius_limit` varchar(100) NOT NULL,
            `houseid` int NOT NULL AUTO_INCREMENT,
            `furniture` LONGTEXT NOT NULL DEFAULT 'none',
            `doors` LONGTEXT NOT NULL DEFAULT 'none',
            `allowed_ids` LONGTEXT NOT NULL DEFAULT 'none',
            `invlimit` varchar(50) NOT NULL DEFAULT 200,
            `player_source_spawnedfurn` varchar(50) NOT NULL DEFAULT 'none',
            `taxes_collected` varchar(50) NOT NULL DEFAULT 'false',
            `ledger` int NOT NULL DEFAULT 0,
            `tax_amount` int NOT NULL DEFAULT 0,
            PRIMARY KEY `houseid` (`houseid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `bcchousinghotels` (
            `charidentifier` varchar(50) NOT NULL,
            `hotels` LONGTEXT NOT NULL DEFAULT 'none'
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await("ALTER TABLE `bcchousing` ADD COLUMN IF NOT EXISTS (`tpInt` int(10) DEFAULT 0)")
    MySQL.query.await("ALTER TABLE `bcchousing` ADD COLUMN IF NOT EXISTS (`tpInstance` int(10) DEFAULT 0)")

    DbUpdated = true

    print("Database tables for \x1b[35m\x1b[1m*bcc-housing*\x1b[0m created or updated \x1b[32msuccessfully\x1b[0m.")

end)