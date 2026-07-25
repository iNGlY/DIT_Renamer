import webview
import json
import os
import re
import shutil
import subprocess
import sys
import time
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

# 全局变量以控制窗口和主线程
main_window = None

class Api:
    def get_history_path(self):
        if getattr(sys, 'frozen', False):
            exe_dir = os.path.dirname(sys.executable)
        else:
            exe_dir = os.path.dirname(os.path.realpath(__file__))
        return os.path.join(exe_dir, "dit_rename_history.json")

    def load_history(self):
        path = self.get_history_path()
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    return json.load(f)
            except:
                return []
        return []

    def save_history(self, history):
        path = self.get_history_path()
        try:
            with open(path, "w", encoding="utf-8") as f:
                json.dump(history, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"保存历史记录失败: {e}")

    # ================= 硬件卡片识别与复用统计 =================
    def get_volume_serial(self, volume_path):
        if not volume_path or not os.path.exists(volume_path):
            return None
        try:
            # 1. 运行 diskutil info 获取该分区的父级物理盘
            res = subprocess.run(["diskutil", "info", volume_path], capture_output=True, text=True)
            if res.returncode != 0:
                return None
            
            part_of_whole = None
            for line in res.stdout.splitlines():
                if "Part of Whole:" in line:
                    part_of_whole = line.split(":", 1)[1].strip()
                    break
            
            if not part_of_whole:
                for line in res.stdout.splitlines():
                    if "Device Identifier:" in line:
                        part_of_whole = line.split(":", 1)[1].strip()
                        break
            
            if part_of_whole:
                # 2. 读取整个物理父盘的信息，以提取固定的硬件序列号
                res_whole = subprocess.run(["diskutil", "info", part_of_whole], capture_output=True, text=True)
                if res_whole.returncode == 0:
                    for line in res_whole.stdout.splitlines():
                        if "Serial Number" in line:
                            val = line.split(":", 1)[1].strip()
                            if val and val != "n/a":
                                return val
                        if "Media UUID" in line:
                            val = line.split(":", 1)[1].strip()
                            if val and val != "n/a":
                                return val
            
            # 备选：如果读不到硬件序列号，则读取分区的 Volume UUID
            for line in res.stdout.splitlines():
                if "Volume UUID:" in line:
                    val = line.split(":", 1)[1].strip()
                    if val and val != "n/a":
                        return val
        except Exception as e:
            print(f"获取磁盘序列号失败: {e}")
        return None

    def calculate_reuse_count(self, serial_number):
        if not serial_number:
            return 0
        history = self.load_history()
        count = 0
        for entry in history:
            if entry.get("serial_number") == serial_number:
                count += 1
        return count

    # ================= 卷监控与重命名逻辑 =================
    def detect_card_brand(self, volume_path):
        if not volume_path or not os.path.exists(volume_path):
            return "Generic"
            
        name = os.path.basename(volume_path)
        name_lower = name.lower()
        
        # 1. 检查是否为相机默认盘符或已重命名的 DIT 卷名格式 (如 A001)
        generic_names = {"untitled", "dji", "no name", "eos_digital", "sony", "sony_card", "canon", "nikon", "sd", "cfx", "cfexpress"}
        dit_pattern = re.match(r'^[A-Z][0-9]{3}$', name)
        
        is_suspected_card = False
        if dit_pattern:
            is_suspected_card = True
        else:
            for g_name in generic_names:
                if g_name in name_lower:
                    is_suspected_card = True
                    break
                    
        # 🛡️ 安全核心：如果既不是相机默认盘名，也不符合 DIT 卷名规范，
        # 则高度怀疑是用户的备份硬盘、RAID 或工作缓存 SSD。
        # 直接跳过一切根目录读取，彻底防止硬盘因读取而电机起转、拉低电压导致拓展坞非正常推出！
        if not is_suspected_card:
            return "Generic"
            
        # 2. 仅对高度疑似卡盘的对象执行特征文件夹与文件检测
        # 检查 SONY 特征
        sony_indicators = [
            os.path.join(volume_path, "PRIVATE", "M4ROOT"),
            os.path.join(volume_path, "M4ROOT"),
            os.path.join(volume_path, "AVCHD"),
            os.path.join(volume_path, "DCIM", "100MSDCF"),
        ]
        for path in sony_indicators:
            if os.path.exists(path):
                return "Sony"
                
        # 检查 DJI 特征
        dji_indicators = [
            os.path.join(volume_path, "DCIM", "100MEDIA"),
            os.path.join(volume_path, "DCIM", "100DJI"),
            os.path.join(volume_path, "PANORAMA"),
        ]
        for path in dji_indicators:
            if os.path.exists(path):
                return "DJI"
                
        try:
            # 扫描根目录下是否有 DJI 或 SONY 前缀文件
            for item in os.listdir(volume_path):
                item_lower = item.lower()
                if item_lower.startswith("dji"):
                    return "DJI"
                if item_lower.startswith("sony") or "msdcf" in item_lower:
                    return "Sony"
            
            # 扫描 DCIM 目录
            dcim_path = os.path.join(volume_path, "DCIM")
            if os.path.exists(dcim_path) and os.path.isdir(dcim_path):
                for sub in os.listdir(dcim_path):
                    sub_lower = sub.lower()
                    if "dji" in sub_lower or "media" in sub_lower:
                        return "DJI"
                    if "sony" in sub_lower or "msdcf" in sub_lower:
                        return "Sony"
        except:
            pass
            
        return "Generic"

    def get_volumes(self):
        volumes = []
        volumes_dir = "/Volumes"
        if os.path.exists(volumes_dir):
            for name in os.listdir(volumes_dir):
                if name.startswith(".") or name in ["Macintosh HD", "Preboot", "Recovery"]:
                    continue
                path = os.path.join(volumes_dir, name)
                if os.path.islink(path) or not os.path.isdir(path):
                    continue
                
                # 预先判断是否为疑似相机卡，如果是备份盘，直接绕过 statvfs/shutil.disk_usage 以免激活磁盘
                name_lower = name.lower()
                generic_names = {"untitled", "dji", "no name", "eos_digital", "sony", "sony_card", "canon", "nikon", "sd", "cfx", "cfexpress"}
                dit_pattern = re.match(r'^[A-Z][0-9]{3}$', name)
                
                is_suspected_card = False
                if dit_pattern:
                    is_suspected_card = True
                else:
                    for g_name in generic_names:
                        if g_name in name_lower:
                            is_suspected_card = True
                            break
                            
                try:
                    if is_suspected_card:
                        total, used, free = shutil.disk_usage(path)
                        brand = self.detect_card_brand(path)
                    else:
                        # 对于确定是备份盘的设备，直接赋予 0 值，避开任何物理磁盘读写
                        total, used, free = 0, 0, 0
                        brand = "Generic"
                        
                    generic_names_check = ["untitled", "dji", "no name", "snd", "audio", "record", "eos_digital", "nocname"]
                    is_generic = name.lower() in generic_names_check or name.lower().startswith("untitled")
                    
                    volumes.append({
                        "name": name,
                        "path": path,
                        "total": total,
                        "free": free,
                        "is_generic": is_generic,
                        "brand": brand
                    })
                except:
                    continue
        return volumes

    def scan_volume(self, volume_path):
        if not volume_path.startswith("/Volumes/"):
            return {"error": "非法路径"}
        
        # 1. 检测硬件序列号并获取历史复用次数
        serial_number = self.get_volume_serial(volume_path)
        reuse_count = self.calculate_reuse_count(serial_number)
        
        video_extensions = ('.mp4', '.mov', '.mxf', '.raw', '.ari', '.arx', '.r3d')
        clip_paths = []
        search_dirs = [
            os.path.join(volume_path, "PRIVATE", "M4ROOT", "CLIP"),
            os.path.join(volume_path, "M4ROOT", "CLIP"),
            os.path.join(volume_path, "DCIM"),
            volume_path
        ]
        
        for s_dir in search_dirs:
            if os.path.exists(s_dir):
                for root, dirs, files in os.walk(s_dir):
                    dirs[:] = [d for d in dirs if not d.startswith('.')]
                    for file in files:
                        if file.lower().endswith(video_extensions) and not file.startswith('.'):
                            full_path = os.path.join(root, file)
                            clip_paths.append((file, full_path))
                            if len(clip_paths) >= 100:
                                break
                    if len(clip_paths) >= 100:
                        break
                if clip_paths:
                    break

        if not clip_paths:
            return {
                "detected": False,
                "clip_count": 0,
                "sample_filename": None,
                "camera_letter": "",
                "roll_number": "",
                "suggested_name": "",
                "device_type": "Generic",
                "explanation": "卡内未发现任何主流视频文件。请手动指定机位号与卷号。",
                "first_clip_name": "",
                "first_clip_time": 0.0,
                "last_clip_name": "",
                "last_clip_time": 0.0,
                "serial_number": serial_number,
                "reuse_count": reuse_count
            }

        clip_paths.sort(key=lambda x: x[0])
        first_clip_name, first_clip_path = clip_paths[0]
        last_clip_name, last_clip_path = clip_paths[-1]

        try:
            first_clip_time = os.path.getmtime(first_clip_path)
            last_clip_time = os.path.getmtime(last_clip_path)
        except:
            first_clip_time = 0.0
            last_clip_time = 0.0

        device_type = "Generic"
        if os.path.exists(os.path.join(volume_path, "PRIVATE", "M4ROOT")) or os.path.exists(os.path.join(volume_path, "M4ROOT")):
            device_type = "Sony"
        elif any("dji" in f[0].lower() for f in clip_paths) or "dji" in os.path.basename(volume_path).lower():
            device_type = "DJI"

        camera_letter = ""
        roll_number = ""
        match = re.match(r'^([A-Za-z])_?([0-9]{3})', first_clip_name)
        if match:
            camera_letter = match.group(1).upper()
            roll_number = match.group(2)

        suggested_name = f"{camera_letter}{roll_number}" if (camera_letter and roll_number) else ""
        explanation = ""

        if suggested_name:
            explanation = f"读取素材文件名 {first_clip_name} 自动分析成功！检测到为机位 [{camera_letter}] 卷号 [{roll_number}]。"
        else:
            history = self.load_history()
            matching_history = [e for e in history if e.get("device_type") == device_type]
            matching_history.sort(key=lambda x: x.get("timestamp", 0.0), reverse=True)
            
            if matching_history and device_type != "Generic":
                last_entry = matching_history[0]
                last_camera = last_entry.get("camera_letter", "A")
                last_roll_str = last_entry.get("roll_number", "000")
                try:
                    last_roll = int(last_roll_str)
                    next_roll = last_roll + 1
                    next_roll_str = f"{next_roll:03d}"
                    camera_letter = last_camera
                    roll_number = next_roll_str
                    suggested_name = f"{camera_letter}{roll_number}"
                    
                    last_clip = last_entry.get("last_clip_name", "")
                    last_digits = re.findall(r'\d+', last_clip)
                    first_digits = re.findall(r'\d+', first_clip_name)
                    
                    is_sequential = False
                    if last_digits and first_digits:
                        try:
                            last_num = int(last_digits[-1])
                            first_num = int(first_digits[-1])
                            if first_num == last_num + 1:
                                is_sequential = True
                        except:
                            pass
                    
                    if is_sequential:
                        explanation = f"分析指纹：检测到 {device_type} 设备。新素材镜头 ({first_clip_name}) 与上一卷 ({last_clip}) 序号完全相连，已智能推荐下一卷: {suggested_name}。"
                    else:
                        explanation = f"分析指纹：检测到 {device_type} 设备。拍摄时间晚于该机型的上一张卡 ({last_entry.get('new_name', '')})，已智能推荐下一卷: {suggested_name}。"
                except:
                    pass

        if not suggested_name:
            explanation = f"发现 {len(clip_paths)} 个视频文件，但均为通用名称 (首个文件: {first_clip_name})。未检测到历史参考，请手动指定机位号与卷号。"

        return {
            "detected": True if suggested_name else False,
            "clip_count": len(clip_paths),
            "sample_filename": first_clip_name,
            "camera_letter": camera_letter,
            "roll_number": roll_number,
            "suggested_name": suggested_name,
            "device_type": device_type,
            "explanation": explanation,
            "first_clip_name": first_clip_name,
            "first_clip_time": first_clip_time,
            "last_clip_name": last_clip_name,
            "last_clip_time": last_clip_time,
            "serial_number": serial_number,
            "reuse_count": reuse_count
        }

    def rename_volume(self, params):
        path = params.get("path")
        new_name = params.get("new_name")
        reuse_count = params.get("reuse_count", 0)
        if not path or not new_name:
            return {"success": False, "message": "参数不完整"}
        if not path.startswith("/Volumes/"):
            return {"success": False, "message": "非法路径"}
        
        new_name = re.sub(r'[^A-Za-z0-9]', '', new_name).upper()
        if not new_name:
            return {"success": False, "message": "卷名非法"}

        # 重新计算序列号以防中途变化
        serial_number = self.get_volume_serial(path)

        result = subprocess.run(["diskutil", "rename", path, new_name], capture_output=True, text=True)
        if result.returncode == 0:
            history = self.load_history()
            entry = {
                "timestamp": time.time(),
                "old_name": params.get("old_name", ""),
                "new_name": new_name,
                "camera_letter": params.get("camera_letter", ""),
                "roll_number": params.get("roll_number", ""),
                "device_type": params.get("device_type", "Generic"),
                "first_clip_name": params.get("first_clip_name", ""),
                "first_clip_time": params.get("first_clip_time", 0.0),
                "last_clip_name": params.get("last_clip_name", ""),
                "last_clip_time": params.get("last_clip_time", 0.0),
                "clip_count": params.get("clip_count", 0),
                "used_size": params.get("used_size", 0),
                "serial_number": serial_number,
            }
            history.append(entry)
            self.save_history(history)
            
            # 手动重命名成功后，返回结果
            return {"success": True, "message": "重命名成功"}
        else:
            return {"success": False, "message": f"重命名失败: {result.stderr.strip()}"}

    def get_history(self):
        history = self.load_history()
        history.sort(key=lambda x: x.get("timestamp", 0.0), reverse=True)
        return history

    def eject_volume(self, volume_path):
        if not volume_path.startswith("/Volumes/"):
            return {"success": False, "message": "非法路径"}
        
        result = subprocess.run(
            ["diskutil", "eject", volume_path],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return {"success": True, "message": "已安全推出卡卷并让读卡器休眠"}
        else:
            error_msg = result.stderr.strip() or "未知错误"
            return {"success": False, "message": f"推出失败: {error_msg}"}

# ================= 开启本地 Webhook 接口监听 Silverstack =================
class WebhookHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_POST(self):
        if self.path == "/api/silverstack_webhook":
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            try:
                data = json.loads(post_data.decode('utf-8'))
                
                # 1. 解析卡卷号与机位
                roll_name = data.get("roll_name", "UNKNOWN").upper()
                camera_letter = roll_name[0] if len(roll_name) > 0 and roll_name[0].isalpha() else "A"
                roll_number = roll_name[1:] if len(roll_name) > 1 and roll_name[1:].isdigit() else "000"
                
                # 2. 尝试从传入的路径或已重命名的盘符中匹配硬件序列号
                api = Api()
                volume_path = data.get("volume_path", f"/Volumes/{roll_name}")
                serial_number = api.get_volume_serial(volume_path)
                
                # 计算自检复用次数
                reuse_count = api.calculate_reuse_count(serial_number)
                
                # 3. 录入历史
                history = api.load_history()
                timestamp = time.time()
                
                entry = {
                    "timestamp": timestamp,
                    "old_name": "Silverstack Ingest",
                    "new_name": roll_name,
                    "camera_letter": camera_letter,
                    "roll_number": roll_number,
                    "device_type": "Silverstack",
                    "first_clip_name": data.get("first_clip", ""),
                    "first_clip_time": timestamp,
                    "last_clip_name": data.get("last_clip", ""),
                    "last_clip_time": timestamp,
                    "clip_count": data.get("clip_count", 0),
                    "used_size": data.get("used_size", 0),
                    "serial_number": serial_number,
                    "reuse_count": reuse_count
                }
                history.append(entry)
                api.save_history(history)
                
                # 4. 通知前端 UI 刷新历史
                global main_window
                if main_window:
                    main_window.evaluate_js("loadHistory()")
                    
                # 5. 打印功能已移除，仅发送成功响应
                
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"success":true}')
            except Exception as e:
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(f'{{"error":"{str(e)}"}}'.encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

def start_webhook_server():
    try:
        server_address = ('127.0.0.1', 8088)
        httpd = HTTPServer(server_address, WebhookHandler)
        t = threading.Thread(target=httpd.serve_forever, daemon=True)
        t.start()
        print("Webhook server bound to http://127.0.0.1:8088")
    except Exception as e:
        print(f"无法启动 Webhook 监听服务器: {e}")

def main():
    global main_window
    api = Api()
    
    start_webhook_server()
    
    if getattr(sys, 'frozen', False):
        dir_path = sys._MEIPASS
        html_path = os.path.join(dir_path, "web", "index.html")
    else:
        dir_path = os.path.dirname(os.path.realpath(__file__))
        html_path = os.path.join(dir_path, "web", "index.html")

    main_window = webview.create_window(
        title="DIT Renamer 现场卡卷重命名与自动化助手 (V0.1 开源专业版)",
        url=html_path,
        js_api=api,
        width=1100,
        height=750,
        min_size=(900, 600),
        background_color='#08080a'
    )
    
    webview.start(debug=False)

if __name__ == "__main__":
    main()
