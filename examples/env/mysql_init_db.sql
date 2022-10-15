CREATE DATABASE `hen` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

use `hen`;

CREATE TABLE `users` (
    `username` VARCHAR(64) NOT NULL,
    `uid` BIGINT NOT NULL,
    PRIMARY KEY (`username`),
    UNIQUE KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `uid_gen` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;