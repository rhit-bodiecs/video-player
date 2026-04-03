import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Scanner;


public class Compress {
    public static final String HEADERNAME = "VIDEO";
    public static String VIDEONAME = "VIDEO";
    public static int CHUNKSIZE = 30000;

    private static int getByte(int[] arr, int idx){
        int out = 0;
        for(int i = 0; i < 8; i++){
            out = (out << 1) | arr[idx + i];
        }
        return out & 0xFF;
    }

    private static void appendHeader(ArrayList<Integer> output, int flag, int count) {
       int header = (flag << 7) | ((count -1) & 0x7F);
       output.add(header);
    }

    private static void appendBytes(ArrayList<Integer> output, int[] pixels, int idx, int numBytes) {
        for(int i = 0; i < numBytes; i++){
             output.add(getByte(pixels, idx + i*8));
        }
    }
    private static void dumpAsmDB(ArrayList<Integer> data) {
        StringBuilder sb = new StringBuilder();
        sb.append(".DB ");

        for (int i = 0; i < data.size(); i++) {
            sb.append(String.format("$%02X", data.get(i) & 0xFF));
            if (i != data.size() - 1) {
                sb.append(", ");
            }
            if ((i + 1) % 16 == 0) {
                sb.append("\n.DB ");
            }
        }

        System.out.println(sb.toString());
    }

    private static ArrayList<Integer> compress(int[] pixels){
        ArrayList<Integer> output = new ArrayList<>();
        for(int i = 0; i < pixels.length; ){
            int flag, count;
            int currentByte = getByte(pixels, i);
            boolean hasNext = (i + 8 < pixels.length);
            int nextByte = hasNext ? getByte(pixels, i+8) : -1;
            if(currentByte == nextByte){
                flag = 1;
                count = 2;
                while((count < 128) && (i + (count+1)*8 < pixels.length) && (currentByte == getByte(pixels, i+count*8))){
                    count++;
                }
                appendHeader(output, flag, count);
                appendBytes(output, pixels, i, 1);
            }
            else{
                flag = 0;
                count = 1;
                while((count < 128) && (i + (count+1)*8 < pixels.length)){
                    int b1 = getByte(pixels, i + count*8);
                    int b2 = getByte(pixels, i + count*8 + 8);
                    if(b1 == b2) break;
                    count++;
                }
                appendHeader(output, flag, count);
                appendBytes(output, pixels, i, count);
            }
            i += count*8;
        }   
        return output;
    }

    private static void makeFile(byte[] compressedVideo, int dataSize, String headerName, String fileName){
        // Calculate total file size
        int totalSize = 55 + 17 + 2 + dataSize + 2; // header + entry meta + entry data length + data + checksum

        ByteBuffer buf = ByteBuffer.allocate(totalSize);
        buf.order(ByteOrder.LITTLE_ENDIAN);

        // --- Outer header (55 bytes) ---
        buf.put("**TI83F*".getBytes(StandardCharsets.US_ASCII));   // signature
        buf.put(new byte[]{0x1A, 0x0A, 0x00});                     // further signature
        byte[] comment = "comment".getBytes(StandardCharsets.US_ASCII);
        buf.put(comment);
        buf.put(new byte[42 - comment.length]);                    // null pad comment to 42 bytes
        buf.putShort((short)(17 + 2 + dataSize));                  // data section length (excludes checksum)

        // --- Variable entry (17 bytes) ---
        buf.putShort((short)0x000D);                               // storage flag
        buf.putShort((short)(dataSize + 2));                             // variable data length
        buf.put((byte)0x15);                                       // type ID: AppVar
        buf.put(headerName.getBytes(StandardCharsets.US_ASCII));      // name
        buf.put(new byte[8 - headerName.length()]);                                      // null pad name to 8 bytes
        buf.put((byte)0x00);                                       // version
        buf.put((byte)0x80);                                       // archive flag
        buf.putShort((short)(dataSize + 2));                             // variable data length (duplicate)

        // --- Entry data ---
        buf.putShort((short)dataSize);                             // length prefix (third copy)
        buf.put(compressedVideo);                                  // your actual data

        // --- Checksum ---
        int checksum = 0;
        for (int i = 55; i < buf.position(); i++) {
            checksum += (buf.get(i) & 0xFF);
        }
        buf.putShort((short)(checksum & 0xFFFF));

        // --- Write to file ---
        try (FileOutputStream fos = new FileOutputStream(fileName)) {
            fos.write(buf.array());
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public static void main(String[] args) {
	if(args.length >= 1){
		VIDEONAME = args[0];
	}
	if(args.length >= 2){
		CHUNKSIZE = Integer.parseInt(args[1]);
	}
        int[] pixels = new int[6144];
        ArrayList<ArrayList<Integer>> videoData = new ArrayList<>();
        //int[] pixels = new int[72];
        int idx = 0;
        File fileObj = new File("videodata.txt"); 
        try (Scanner myReader = new Scanner(fileObj)) {
            while (myReader.hasNextLine()) {
                String data = myReader.nextLine();
                String[] dataStrings = data.split(",");
                for(String word : dataStrings){
                    pixels[idx] = Integer.parseInt(word);
                    idx++;
                }
                videoData.add(compress(pixels));
                idx = 0;
            }
        } catch (FileNotFoundException e) {
            System.out.println("An error occurred: The file was not found.");
            e.printStackTrace();
        }
        //System.out.println(videoData.get(0).size());
        //System.out.println(videoData.size());
        //dumpAsmDB(videoData.get(0));

        // int sizeBytes = 0;
        // for(ArrayList<Integer> frame : videoData){
        //     sizeBytes += frame.size();
        // }

        // byte[] compressedVideo = new byte[sizeBytes];
        // int pos = 0;
        // for(ArrayList<Integer> frame : videoData){
        //     for(int b : frame){
        //         compressedVideo[pos++] = (byte)(b & 0xFF);
        //     }
        // }
        for(ArrayList<Integer> frame : videoData){
            if(frame.size() > 768) System.out.println(frame.size());
        }
        
        int sizeBytes = 0;
        int chunkStart = 0;
        char chunkNumber = 'a';

        for(int frameNum = 0; frameNum < videoData.size(); frameNum++){
            ArrayList<Integer> frame = videoData.get(frameNum);
            
            if(sizeBytes + frame.size() > CHUNKSIZE && sizeBytes > 0){
                // Write current chunk (from chunkStart to frameNum-1)
                byte[] compressedVideo = new byte[sizeBytes];
                int pos = 0;
                for(int i = chunkStart; i < frameNum; i++){
                    for(int j = 0; j < videoData.get(i).size(); j++){
                        compressedVideo[pos++] = (byte)(videoData.get(i).get(j) & 0xFF);
                    }
                }
                makeFile(compressedVideo, sizeBytes, 
                        HEADERNAME + chunkNumber, 
                        VIDEONAME + chunkNumber + ".8xv");
                
                chunkNumber++;
                chunkStart = frameNum;
                sizeBytes = 0;
            }
            
            sizeBytes += frame.size();
        }

        // Write final chunk
        if(sizeBytes > 0){
            byte[] compressedVideo = new byte[sizeBytes];
            int pos = 0;
            for(int i = chunkStart; i < videoData.size(); i++){
                for(int j = 0; j < videoData.get(i).size(); j++){
                    compressedVideo[pos++] = (byte)(videoData.get(i).get(j) & 0xFF);
                }
            }
            makeFile(compressedVideo, sizeBytes, 
                    HEADERNAME + chunkNumber, 
                    VIDEONAME + chunkNumber + ".8xv");
        }
        
        

        // ArrayList<Integer> output = new ArrayList<>();
        // output = compress(pixels);
        
        // System.out.println(output);
        // System.out.println(output.size());

        // int[] uncompressed = new int[6144];
        // int bitPos = 0;

        // for (int i = 0; i < output.size(); ) {
        //     int header = output.get(i);
        //     int count = (header & 0x7F) + 1;

        //     if ((header & 0x80) != 0) { // run
        //         int valueByte = output.get(i + 1);
        //         for (int j = 0; j < count; j++) {
        //             for (int b = 0; b < 8; b++) {
        //                 uncompressed[bitPos++] = (valueByte >> (7 - b)) & 1;
        //             }
        //         }
        //         i += 2;
        //     } else { // literal
        //         for (int j = 0; j < count; j++) {
        //             int valueByte = output.get(i + 1 + j);
        //             for (int b = 0; b < 8; b++) {
        //                 uncompressed[bitPos++] = (valueByte >> (7 - b)) & 1;
        //             }
        //         }
        //         i += count + 1;
        //     }
        // }

        // if (Arrays.equals(uncompressed, pixels))
        //     System.out.println("success");
        // else
        //     System.out.println("Failed");

        }
}
