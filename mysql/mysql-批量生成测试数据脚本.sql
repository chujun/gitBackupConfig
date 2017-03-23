-- 1.创建一个临时内存表, 做数据插入的时候会比较快些
-- 创建一个临时内存表
DROP TABLE IF EXISTS `vote_record_memory`;
CREATE TABLE `vote_record_memory` (
    `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `user_id` varchar(20) NOT NULL DEFAULT '',
    `vote_num` int(10) unsigned NOT NULL DEFAULT '0',
    `group_id` int(10) unsigned NOT NULL DEFAULT '0',
    `status` tinyint(2) unsigned NOT NULL DEFAULT '1',
    `create_time` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
    PRIMARY KEY (`id`),
    KEY `index_user_id` (`user_id`) USING HASH
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

--  2.创建一个普通表，用作模拟大数据的测试用例
DROP TABLE IF EXISTS `vote_record`;
CREATE TABLE `vote_record` (
    `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `user_id` varchar(20) NOT NULL DEFAULT '' COMMENT '用户Id',
    `vote_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '投票数',
    `group_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '用户组id 0-未激活用户 1-普通用户 2-vip用户 3-管理员用户',
    `status` tinyint(2) unsigned NOT NULL DEFAULT '1' COMMENT '状态 1-正常 2-已删除',
    `create_time` datetime NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
    PRIMARY KEY (`id`),
    KEY `index_user_id` (`user_id`) USING HASH COMMENT '用户ID哈希索引'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='投票记录表';


-- 3.为了数据的随机性和真实性，我们需要创建一个可生成长度为n的随机字符串的函数
-- 创建生成长度为n的随机字符串的函数
-- DELIMITER:告诉mysql解释器，该段命令是否已经结束了，mysql是否可以执行了。默认情况下，delimiter是分号;。在命令行客户端中，如果有一行命令以分号结束，那么回车后，mysql将会立刻执行该命令。
DELIMITER // -- 修改MySQL delimiter 由默认的分号改为双斜杠
DROP FUNCTION IF EXISTS `rand_string`;
SET NAMES utf8 //
CREATE FUNCTION `rand_string` (n INT) RETURNS VARCHAR(255) CHARSET 'utf8'
BEGIN
    DECLARE char_str varchar(100) DEFAULT 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    DECLARE return_str varchar(255) DEFAULT '';
    DECLARE i INT DEFAULT 0;
    WHILE i < n DO
        SET return_str = concat(return_str, substring(char_str, FLOOR(1 + RAND()*62), 1));
        SET i = i+1;
    END WHILE;
    RETURN return_str;
END //

-- 4.为了操作方便，我们再创建一个插入数据的存储过程
-- 创建插入数据的存储过程
DROP PROCEDURE IF EXISTS `add_vote_record_memory` //
CREATE PROCEDURE `add_vote_record_memory`(IN n INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE vote_num INT DEFAULT 0;
    DECLARE group_id INT DEFAULT 0;
    DECLARE status TINYINT DEFAULT 1;
    WHILE i < n DO
        SET vote_num = FLOOR(1 + RAND() * 10000);
        SET group_id = FLOOR(0 + RAND()*3);
        SET status = FLOOR(1 + RAND()*2);
        INSERT INTO `vote_record_memory` VALUES (NULL, rand_string(20), vote_num, group_id, status, NOW());
        SET i = i + 1;
    END WHILE;
END //
DELIMITER ;  -- 改回默认的 MySQL delimiter：';'

-- 5.开始执行存储过程，等待生成数据(100W条生成大约需要近4分钟)
-- 调用存储过程 生成100W条数据
CALL add_vote_record_memory(1000000);

-- 6.查询内存表已生成记录(为了下步测试，目前仅生成了105645条)
SELECT count(*) FROM `vote_record_memory`;
-- count(*)
-- 105646

-- 7.把数据从内存表插入到普通表中(100w条数据13s就插入完了)
INSERT INTO vote_record SELECT * FROM `vote_record_memory`;


-- 8.查询普通表已的生成记录
SELECT count(*) FROM `vote_record`;
-- count(*)
-- 105646

-- 9.如果一次性插入普通表太慢，可以分批插入，这就需要写个存储过程了：
-- 参数n是每次要插入的条数
-- lastid是已导入的最大id
DELIMITER //
DROP PROCEDURE IF EXISTS `copy_data_from_tmp` //
CREATE PROCEDURE `copy_data_from_tmp`(IN n INT)
BEGIN
    DECLARE lastid INT DEFAULT 0;
    SELECT MAX(id) INTO lastid FROM `vote_record`;
    INSERT INTO `vote_record` SELECT * FROM `vote_record_memory` where id > lastid LIMIT n;
END //
DELIMITER ;

-- 10.调用存储过程
-- 调用存储过程 插入60w条
CALL copy_data_from_tmp(600000);